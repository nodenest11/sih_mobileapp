import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/location.dart';
import 'api_service.dart';
import 'background_location_service.dart';
import 'fcm_notification_service.dart';
import '../utils/logger.dart';

class LocationService {
  static const int _locationUpdateInterval = 300; // seconds (5 minutes)
  
  final ApiService _apiService = ApiService();
  final FCMNotificationService _notificationService = FCMNotificationService();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _updateTimer;
  String? _currentTouristId;
  
  Position? _lastKnownPosition;
  final StreamController<LocationData> _locationController = StreamController<LocationData>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isTracking => _positionSubscription != null || _updateTimer != null;

  // Helper method to safely add status updates
  void _addStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
      AppLogger.service('Location Status: $status');
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
      
      // Get human-readable address using reverse geocoding
      String address;
      try {
        address = await _apiService.reverseGeocode(
          lat: position.latitude,
          lon: position.longitude,
        );
      } catch (e) {
        // Fallback to coordinates if reverse geocoding fails
        address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
      
      // Create a formatted location response
      final locationInfo = {
        'position': position,
        'lat': position.latitude,
        'lng': position.longitude,
        'address': address,
        'coordinates': '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        'accuracy': '±${position.accuracy.round()}m',
        'timestamp': DateTime.now(),
      };

      _addStatus('Location sharing active');
      return locationInfo;
    } catch (e) {
      _addStatus('Your location will be sharing');
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
      _addStatus('Location services are disabled. Please enable them.');
      return false;
    }

    // Check location permissions
    locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
      if (locationPermission == LocationPermission.denied) {
        _addStatus('Location permissions are denied.');
        return false;
      }
    }

    if (locationPermission == LocationPermission.deniedForever) {
      _addStatus('Location permissions are permanently denied. Please enable them in settings.');
      return false;
    }

    // Request background location permission (Android 10+)
    final backgroundLocationStatus = await Permission.locationAlways.request();
    if (backgroundLocationStatus != PermissionStatus.granted) {
      _addStatus('Background location permission is required for continuous tracking.');
      // Continue anyway as some devices might still work
    }

    // Request notification permissions
    final notificationStatus = await Permission.notification.request();
    if (notificationStatus != PermissionStatus.granted) {
      _addStatus('Notification permission denied. You may not see tracking status.');
    }

    // Request ignore battery optimization
    final ignoreBatteryStatus = await Permission.ignoreBatteryOptimizations.request();
    if (ignoreBatteryStatus != PermissionStatus.granted) {
      _addStatus('Please disable battery optimization for continuous tracking.');
    }

    _addStatus('Location permissions granted.');
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
      _addStatus('Failed to get current location: $e');
      return null;
    }
  }

  // Start live location tracking with background service
  Future<void> startTracking() async {
    if (isTracking) {
      await stopTracking();
    }

    // Initialize API service with authentication
    await _apiService.initializeAuth();
    
    _addStatus('Initializing location services...');
    
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return;

    _addStatus('Your location will be sharing');

    try {
      // Get initial current location immediately
      final currentPosition = await getCurrentLocation();
      if (currentPosition != null) {
        _addStatus('Location sharing active');
        _handleLocationUpdate(currentPosition);
      }

      // Enable wake lock to prevent device from sleeping
      await WakelockPlus.enable();
      
      // DISABLED: Background service causes isolate errors when app is killed/restarted
      // The foreground service with wake lock is sufficient for location tracking
      // If needed in future, the plugin needs to be updated to handle isolate errors
      /*
      try {
        await BackgroundLocationService.initializeService();
        AppLogger.service('Background location service initialized successfully');
      } catch (e) {
        AppLogger.service('Background service initialization failed', isError: true);
        // Continue without background service if it fails
      }
      */
      AppLogger.service('Using foreground location tracking only (background service disabled)');
      
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
          _addStatus('Location sharing active');
          _handleLocationUpdate(position);
        },
        onError: (error) {
          _addStatus('Location error: $error');
        },
      );

      // Set up periodic updates to backend (every 300 seconds / 5 minutes)
      _updateTimer = Timer.periodic(
        const Duration(seconds: _locationUpdateInterval),
        (timer) async {
          if (_lastKnownPosition != null) {
            await _sendLocationToBackend(_lastKnownPosition!);
            // Show silent notification after location is shared
            await _notificationService.showSilentLocationNotification(
              latitude: _lastKnownPosition!.latitude,
              longitude: _lastKnownPosition!.longitude,
            );
          }
        },
      );

    } catch (e) {
      _addStatus('Failed to start tracking: $e');
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
    
    // Stop background service
    await BackgroundLocationService.stopService();
    
    // Safely add status if controller is not closed
    if (!_statusController.isClosed) {
      _addStatus('Location tracking and background service stopped.');
    }
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

    // Safely add to stream if controller is not closed
    if (!_locationController.isClosed) {
      _locationController.add(locationData);
    }
  }

  // Send location update to backend
  Future<void> _sendLocationToBackend(Position position) async {
    try {
      final response = await _apiService.updateLocation(
        lat: position.latitude,
        lon: position.longitude,
        speed: position.speed,
        altitude: position.altitude,
        accuracy: position.accuracy,
        timestamp: DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch),
      );

      if (response['success'] == true) {
        _addStatus('Location updated - Safety: ${response['safety_score']}');
      } else {
        _addStatus('Location update failed');
      }
    } catch (e) {
      _addStatus('Failed to update location to backend: $e');
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
