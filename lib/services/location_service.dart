import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location.dart';
import 'api_service.dart';
import 'background_location_service.dart';

class LocationService {
  static const int _locationUpdateInterval = 60; // seconds
  static const String _logTag = '[LocationService]';
  
  final ApiService _apiService = ApiService();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _updateTimer;
  String? _currentTouristId;
  bool _backgroundServiceRunning = false;
  
  Position? _lastKnownPosition;
  final StreamController<LocationData> _locationController = StreamController<LocationData>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isTracking =>
      _backgroundServiceRunning || _positionSubscription != null || _updateTimer != null;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('$_logTag $message');
    }
  }

  // Get current location with formatted address
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      _lastKnownPosition = position;
      
      // Create a formatted location response
      final locationInfo = {
        'position': position,
        'address': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        'accuracy': '±${position.accuracy.round()}m',
        'timestamp': DateTime.now(),
      };

      _statusController.add('Current location: ${locationInfo['address']}');
      _log('Fetched current location ${locationInfo['address']} accuracy ${position.accuracy}m.');
      return locationInfo;
    } catch (e) {
      _statusController.add('Your location will be sharing');
      _log('Failed to fetch current location: $e');
      return null;
    }
  }

  // Check and request all necessary permissions including background location
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission locationPermission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _statusController.add('Location services are disabled. Please enable them.');
      return false;
    }

    // Check location permissions
    locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
      if (locationPermission == LocationPermission.denied) {
        _statusController.add('Location permissions are denied.');
        return false;
      }
    }

    if (locationPermission == LocationPermission.deniedForever) {
      _statusController.add('Location permissions are permanently denied. Please enable them in settings.');
      return false;
    }

    // Request background location permission (Android 10+)
    final backgroundLocationStatus = await Permission.locationAlways.request();
    if (backgroundLocationStatus != PermissionStatus.granted) {
      _statusController.add('Background location permission is required for continuous tracking.');
      // Continue anyway as some devices might still work
    }

    // Request notification permissions
    final notificationStatus = await Permission.notification.request();
    if (notificationStatus != PermissionStatus.granted) {
      _statusController.add('Notification permission denied. You may not see tracking status.');
    }

    // Request ignore battery optimization
    final ignoreBatteryStatus = await Permission.ignoreBatteryOptimizations.request();
    if (ignoreBatteryStatus != PermissionStatus.granted) {
      _statusController.add('Please disable battery optimization for continuous tracking.');
    }

    _statusController.add('Location permissions granted.');
    _log('Permissions granted (serviceEnabled=$serviceEnabled, locationPermission=$locationPermission).');
    return true;
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      _statusController.add('Failed to get current location: $e');
      _log('Failed to get current location: $e');
      return null;
    }
  }

  // Start live location tracking with background service
  Future<void> startTracking(String touristId) async {
    if (isTracking) {
      await stopTracking();
    }

    _currentTouristId = touristId;
    
    // Save tourist ID to preferences for background service
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tourist_id', touristId);
    
  _statusController.add('Initializing location services...');
  _log('startTracking invoked for touristId=$touristId.');
    
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return;

    _statusController.add('Your location will be sharing');

    try {
      // Get initial current location immediately
      final currentPosition = await getCurrentLocation();
      if (currentPosition != null) {
        _statusController.add('Location sharing active');
        _handleLocationUpdate(currentPosition);
        _log('Initial location lat=${currentPosition.latitude}, lng=${currentPosition.longitude}.');
      }

      // Enable wake lock to prevent device from sleeping
      await WakelockPlus.enable();
      _log('Wakelock enabled.');
      
      // Initialize and start background location service
      _backgroundServiceRunning =
          await BackgroundLocationService.initializeService();
      _log('Background service running: $_backgroundServiceRunning.');
      
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update when user moves 5 meters
      );

      // Start continuous location tracking for foreground updates
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastKnownPosition = position;
          _statusController.add('Location sharing active');
          _handleLocationUpdate(position);
          _log('Foreground update lat=${position.latitude}, lng=${position.longitude}, acc=${position.accuracy}.');
        },
        onError: (error) {
          _statusController.add('Location error: $error');
          _log('Foreground stream error: $error');
        },
      );

      // Set up periodic updates to backend (every 60 seconds)
      _updateTimer = Timer.periodic(
        const Duration(seconds: _locationUpdateInterval),
        (timer) {
          if (_lastKnownPosition != null) {
            _sendLocationToBackend(_lastKnownPosition!);
            _log('Foreground timer triggered backend update.');
          } else {
            _log('Foreground timer fired with no lastKnownPosition.');
          }
        },
      );

    } catch (e) {
      _statusController.add('Failed to start tracking: $e');
      _log('Failed to start tracking: $e');
    }
  }

  // Stop location tracking and background service
  Future<void> stopTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    // Disable wake lock
    await WakelockPlus.disable();
    _log('Wakelock disabled.');
    
    // Stop background service
    await BackgroundLocationService.stopService();
    _backgroundServiceRunning = false;
    
    _statusController.add('Location tracking and background service stopped.');
    _log('Tracking stopped; background service flag cleared.');
  }

  // Handle location update
  void _handleLocationUpdate(Position position) {
    if (_currentTouristId == null) return;

    final locationData = LocationData(
      touristId: _currentTouristId!,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
    );

    _locationController.add(locationData);
    _log('Emitted LocationData lat=${position.latitude}, lng=${position.longitude}, speed=${position.speed}.');
  }

  // Send location update to backend
  Future<void> _sendLocationToBackend(Position position) async {
    if (_currentTouristId == null) return;

    try {
      final touristIdInt = int.tryParse(_currentTouristId!);
      if (touristIdInt == null) {
        _statusController.add('Invalid tourist ID format');
        return;
      }

      await _apiService.updateLocation(
        touristId: touristIdInt,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _log('Sent backend update lat=${position.latitude}, lng=${position.longitude}.');
    } catch (e) {
      _statusController.add('Failed to update location to backend: $e');
      _log('Failed to update location to backend: $e');
    }
  }

  // Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Check if user is inside a polygon (for geo-fencing)
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      if (_rayCastIntersect(point, polygon[j], polygon[j + 1])) {
        intersectCount++;
      }
    }

    return intersectCount % 2 == 1;
  }

  bool _rayCastIntersect(LatLng point, LatLng vertA, LatLng vertB) {
    double aY = vertA.latitude;
    double bY = vertB.latitude;
    double aX = vertA.longitude;
    double bX = vertB.longitude;
    double pY = point.latitude;
    double pX = point.longitude;

    if ((aY > pY) != (bY > pY) &&
        (pX < (bX - aX) * (pY - aY) / (bY - aY) + aX)) {
      return true;
    }
    return false;
  }

  // Get location settings info
  Future<Map<String, dynamic>> getLocationSettings() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    
    return {
      'serviceEnabled': serviceEnabled,
      'permission': permission.name,
      'isTracking': isTracking,
      'lastUpdate': _lastKnownPosition != null 
          ? DateTime.fromMillisecondsSinceEpoch(_lastKnownPosition!.timestamp.millisecondsSinceEpoch)
          : null,
    };
  }

  void dispose() {
    stopTracking();
    _locationController.close();
    _statusController.close();
    _apiService.dispose();
  }
}