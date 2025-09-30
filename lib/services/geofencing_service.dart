import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';

import '../models/alert.dart';
import '../utils/logger.dart';
import 'api_service.dart';

enum GeofenceEventType {
  enter,
  exit,
}

class GeofenceEvent {
  final RestrictedZone zone;
  final GeofenceEventType eventType;
  final LatLng currentLocation;
  final DateTime timestamp;

  GeofenceEvent({
    required this.zone,
    required this.eventType,
    required this.currentLocation,
    required this.timestamp,
  });
}

class GeofencingService {
  static GeofencingService? _instance;
  static GeofencingService get instance {
    _instance ??= GeofencingService._internal();
    return _instance!;
  }

  GeofencingService._internal();

  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  List<RestrictedZone> _restrictedZones = [];
  Set<String> _currentZones = {}; // Track which zones user is currently in
  StreamController<GeofenceEvent>? _eventController;
  Timer? _locationTimer;
  bool _isMonitoring = false;

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 10); // Check location every 10 seconds

  Stream<GeofenceEvent> get events {
    _eventController ??= StreamController<GeofenceEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Initialize the geofencing service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _loadRestrictedZones();
  }

  /// Initialize notification system
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Load restricted zones from API
  Future<void> _loadRestrictedZones() async {
    try {
      _restrictedZones = await _apiService.getRestrictedZones();
      AppLogger.info('Loaded ${_restrictedZones.length} restricted zones for geofencing');
    } catch (e) {
      AppLogger.error('Failed to load restricted zones for geofencing: $e');
      _restrictedZones = [];
    }
  }

  /// Start monitoring geofences
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    AppLogger.info('Starting geofencing monitoring service...');
    
    // Check location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      AppLogger.warning('Location permission denied, cannot start geofencing');
      return;
    }

    await _loadRestrictedZones();
    
    _isMonitoring = true;
    
    // Start periodic location checking
    _locationTimer = Timer.periodic(_checkInterval, (timer) async {
      await _checkCurrentLocation();
    });
    
    AppLogger.info('Geofencing monitoring started with ${_restrictedZones.length} zones');
  }

  /// Stop monitoring geofences  
  void stopMonitoring() {
    AppLogger.info('Stopping geofencing monitoring...');
    _isMonitoring = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    _currentZones.clear();
  }

  /// Check current location against all restricted zones
  Future<void> _checkCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      final Set<String> newCurrentZones = {};
      
      // Check each restricted zone
      for (final zone in _restrictedZones) {
        final isInside = _isPointInPolygon(currentLocation, zone.polygonCoordinates);
        
        if (isInside) {
          newCurrentZones.add(zone.id);
          
          // Check if this is a new entry
          if (!_currentZones.contains(zone.id)) {
            await _handleZoneEntry(zone, currentLocation);
          }
        } else {
          // Check if this is an exit (was inside before, now outside)
          if (_currentZones.contains(zone.id)) {
            await _handleZoneExit(zone, currentLocation);
          }
        }
      }
      
      _currentZones = newCurrentZones;
      
    } catch (e) {
      // Log geofencing check error for debugging
      AppLogger.error('Geofencing check error: $e');
    }
  }

  /// Handle zone entry event
  Future<void> _handleZoneEntry(RestrictedZone zone, LatLng location) async {
    AppLogger.warning('User entered restricted zone: ${zone.name}');
    
    final event = GeofenceEvent(
      zone: zone,
      eventType: GeofenceEventType.enter,
      currentLocation: location,
      timestamp: DateTime.now(),
    );

    // Emit event
    _eventController?.add(event);
    
    // Trigger haptic feedback
    await _triggerHapticFeedback(zone.type);
    
    // Show notification
    await _showZoneAlert(zone, GeofenceEventType.enter);
  }

  /// Handle zone exit event  
  Future<void> _handleZoneExit(RestrictedZone zone, LatLng location) async {
    AppLogger.info('User exited restricted zone: ${zone.name}');
    
    final event = GeofenceEvent(
      zone: zone,
      eventType: GeofenceEventType.exit,
      currentLocation: location,
      timestamp: DateTime.now(),
    );

    // Emit event
    _eventController?.add(event);
    
    // Light haptic feedback for exit
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      // Vibration not supported on this device
    }
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      
      if (((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) &&
          (point.latitude < (pj.latitude - pi.latitude) * (point.longitude - pi.longitude) / 
           (pj.longitude - pi.longitude) + pi.latitude)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  /// Trigger haptic feedback based on zone type
  Future<void> _triggerHapticFeedback(ZoneType zoneType) async {
    try {
      if (!(await Vibration.hasVibrator())) return;
      
      switch (zoneType) {
        case ZoneType.dangerous:
          // Strong, urgent vibration pattern
          await Vibration.vibrate(
            pattern: [0, 500, 200, 500, 200, 500],
            intensities: [0, 255, 0, 255, 0, 255],
          );
          break;
          
        case ZoneType.highRisk:
          // Medium intensity vibration pattern
          await Vibration.vibrate(
            pattern: [0, 400, 300, 400],
            intensities: [0, 200, 0, 200],
          );
          break;
          
        case ZoneType.restricted:
          // Moderate vibration
          await Vibration.vibrate(
            pattern: [0, 300, 200, 300],
            intensities: [0, 150, 0, 150],
          );
          break;
          
        case ZoneType.caution:
          // Gentle notification vibration
          await Vibration.vibrate(duration: 300);
          break;
          
        case ZoneType.safe:
          // No vibration for safe zones
          break;
      }
    } catch (e) {
      // Vibration not supported on this device
      AppLogger.warning('Vibration not supported: $e');
    }
  }

  /// Show notification alert for zone entry
  Future<void> _showZoneAlert(RestrictedZone zone, GeofenceEventType eventType) async {
    final title = eventType == GeofenceEventType.enter 
        ? '⚠️ Restricted Area Alert' 
        : '✅ Safe Zone';
        
    final body = eventType == GeofenceEventType.enter
        ? (zone.warningMessage?.isNotEmpty ?? false) ? zone.warningMessage! : 'You have entered: ${zone.name}'
        : 'You have left the restricted area: ${zone.name}';

    const androidDetails = AndroidNotificationDetails(
      'geofence_alerts',
      'Geofence Alerts',
      channelDescription: 'Notifications for entering/exiting restricted areas',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  /// Get current zones user is in
  List<String> get currentZoneIds => _currentZones.toList();
  
  /// Get current zone objects
  List<RestrictedZone> get currentZones {
    return _restrictedZones.where((zone) => _currentZones.contains(zone.id)).toList();
  }

  /// Cleanup resources
  void dispose() {
    stopMonitoring();
    _eventController?.close();
    _eventController = null;
  }
}