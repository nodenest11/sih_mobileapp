import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  Set<String> _nearbyZones = {}; // Track which zones user is approaching
  StreamController<GeofenceEvent>? _eventController;
  Timer? _locationTimer;
  bool _isMonitoring = false;

  // Public access to restricted zones for map display
  List<RestrictedZone> get restrictedZones => List.unmodifiable(_restrictedZones);

  // Configuration
  static const Duration _checkInterval = Duration(seconds: 5); // Check location every 5 seconds for faster response
  static const double _nearbyThresholdMeters = 500.0; // Alert when within 500m
  static const double _criticalThresholdMeters = 100.0; // Critical alert when within 100m

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
    // Create high-priority Android notification channel for emergency alerts
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_emergency_alerts',
      'Emergency Zone Alerts',
      description: 'High-priority alerts when entering or approaching restricted/dangerous zones',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF0000),
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

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
      final Set<String> newNearbyZones = {};
      
      // Check each restricted zone
      for (final zone in _restrictedZones) {
        final isInside = _isPointInPolygon(currentLocation, zone.polygonCoordinates);
        
        // Calculate distance to zone center for proximity alerts
        final zoneCenterLat = zone.polygonCoordinates.map((p) => p.latitude).reduce((a, b) => a + b) / zone.polygonCoordinates.length;
        final zoneCenterLng = zone.polygonCoordinates.map((p) => p.longitude).reduce((a, b) => a + b) / zone.polygonCoordinates.length;
        final distanceToZone = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          zoneCenterLat,
          zoneCenterLng,
        );
        
        if (isInside) {
          newCurrentZones.add(zone.id);
          
          // Check if this is a new entry
          if (!_currentZones.contains(zone.id)) {
            await _handleZoneEntry(zone, currentLocation, distanceToZone);
          }
        } else {
          // Check if this is an exit (was inside before, now outside)
          if (_currentZones.contains(zone.id)) {
            await _handleZoneExit(zone, currentLocation);
          }
          
          // Check proximity - critical distance (within 100m)
          if (distanceToZone <= _criticalThresholdMeters) {
            newNearbyZones.add('${zone.id}-critical');
            if (!_nearbyZones.contains('${zone.id}-critical')) {
              await _handleCriticalProximity(zone, currentLocation, distanceToZone);
            }
          }
          // Check proximity - nearby distance (within 500m)
          else if (distanceToZone <= _nearbyThresholdMeters) {
            newNearbyZones.add('${zone.id}-nearby');
            if (!_nearbyZones.contains('${zone.id}-nearby') && !_nearbyZones.contains('${zone.id}-critical')) {
              await _handleNearbyProximity(zone, currentLocation, distanceToZone);
            }
          }
        }
      }
      
      _currentZones = newCurrentZones;
      _nearbyZones = newNearbyZones;
      
    } catch (e) {
      // Log geofencing check error for debugging
      AppLogger.error('Geofencing check error: $e');
    }
  }

  /// Handle zone entry event
  Future<void> _handleZoneEntry(RestrictedZone zone, LatLng location, double distance) async {
    AppLogger.warning('🚨 EMERGENCY: User entered restricted zone: ${zone.name}');
    
    final event = GeofenceEvent(
      zone: zone,
      eventType: GeofenceEventType.enter,
      currentLocation: location,
      timestamp: DateTime.now(),
    );

    // Emit event
    _eventController?.add(event);
    
    // Trigger EMERGENCY haptic feedback
    await _triggerHapticFeedback(zone.type);
    
    // Show HIGH-PRIORITY notification
    await _showEmergencyZoneAlert(zone, distance, isInside: true);
  }

  /// Handle critical proximity (within 100m)
  Future<void> _handleCriticalProximity(RestrictedZone zone, LatLng location, double distance) async {
    AppLogger.warning('⚠️ CRITICAL: User within ${distance.toInt()}m of restricted zone: ${zone.name}');
    
    // Trigger strong vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500],
          intensities: [0, 255, 0, 255],
        );
      }
    } catch (e) {
      AppLogger.warning('Vibration not supported: $e');
    }
    
    // Show critical proximity alert
    await _showProximityAlert(zone, distance, isCritical: true);
  }

  /// Handle nearby proximity (within 500m)
  Future<void> _handleNearbyProximity(RestrictedZone zone, LatLng location, double distance) async {
    AppLogger.info('⚠️ WARNING: User within ${distance.toInt()}m of restricted zone: ${zone.name}');
    
    // Trigger warning vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200],
          intensities: [0, 128, 0, 128],
        );
      }
    } catch (e) {
      AppLogger.warning('Vibration not supported: $e');
    }
    
    // Show nearby proximity alert
    await _showProximityAlert(zone, distance, isCritical: false);
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

  /// Show HIGH-PRIORITY emergency notification for zone entry
  Future<void> _showEmergencyZoneAlert(RestrictedZone zone, double distance, {required bool isInside}) async {
    final title = '🚨 EMERGENCY ALERT - ${zone.name}';
    final body = isInside
        ? 'You have ENTERED a restricted zone! Please leave immediately for your safety.'
        : 'DANGER: You are ${distance.toInt()}m from a restricted zone. Do not proceed!';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geofence_emergency_alerts',
      'Emergency Zone Alerts',
      channelDescription: 'High-priority alerts when entering or approaching restricted/dangerous zones',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alert_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      color: const Color(0xFFFF0000),
      ledColor: const Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      showWhen: true,
      autoCancel: false, // Don't auto-dismiss
      ongoing: true, // Keep notification visible
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true, // Show full screen
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'URGENT: Tourist Safety Alert',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final notificationDetails = NotificationDetails(
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

  /// Show proximity alert notification
  Future<void> _showProximityAlert(RestrictedZone zone, double distance, {required bool isCritical}) async {
    final title = isCritical
        ? '🚨 CRITICAL WARNING - Approaching ${zone.name}'
        : '⚠️ WARNING - Near ${zone.name}';
    final body = isCritical
        ? 'You are only ${distance.toInt()}m from a restricted zone! Turn back immediately!'
        : 'You are ${distance.toInt()}m from a restricted area. Exercise extreme caution and avoid entering.';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geofence_emergency_alerts',
      'Emergency Zone Alerts',
      channelDescription: 'High-priority alerts when entering or approaching restricted/dangerous zones',
      importance: isCritical ? Importance.max : Importance.high,
      priority: isCritical ? Priority.max : Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: isCritical
          ? Int64List.fromList([0, 500, 200, 500])
          : Int64List.fromList([0, 200, 100, 200]),
      enableLights: true,
      color: isCritical ? const Color(0xFFFF0000) : const Color(0xFFFF9800),
      ledColor: isCritical ? const Color(0xFFFF0000) : const Color(0xFFFF9800),
      ledOnMs: 1000,
      ledOffMs: 500,
      showWhen: true,
      autoCancel: !isCritical,
      category: isCritical ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      timeoutAfter: isCritical ? null : 30000,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Tourist Safety Alert',
      ),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: isCritical ? InterruptionLevel.critical : InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (isCritical ? 1 : 0),
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
    _restrictedZones.clear();
    _currentZones.clear();
    AppLogger.info('GeofencingService disposed');
  }
}
