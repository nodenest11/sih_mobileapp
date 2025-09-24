import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/location.dart';
import 'api_service.dart';

class LocationService {
  static const int _locationUpdateInterval = 10; // seconds
  
  final ApiService _apiService = ApiService();
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

  // Check and request location permissions
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _statusController.add('Location services are disabled. Please enable them.');
      return false;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _statusController.add('Location permissions are denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _statusController.add('Location permissions are permanently denied. Please enable them in settings.');
      return false;
    }

    _statusController.add('Location permissions granted.');
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
      return null;
    }
  }

  // Start live location tracking
  Future<void> startTracking(String touristId) async {
    if (isTracking) {
      await stopTracking();
    }

    _currentTouristId = touristId;
    
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return;

    _statusController.add('Starting location tracking...');

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update when user moves 5 meters
      );

      // Start continuous location tracking
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastKnownPosition = position;
          _handleLocationUpdate(position);
        },
        onError: (error) {
          _statusController.add('Location tracking error: $error');
        },
      );

      // Also set up periodic updates to backend (every 10 seconds)
      _updateTimer = Timer.periodic(
        const Duration(seconds: _locationUpdateInterval),
        (timer) {
          if (_lastKnownPosition != null) {
            _sendLocationToBackend(_lastKnownPosition!);
          }
        },
      );

      _statusController.add('Location tracking started successfully.');
    } catch (e) {
      _statusController.add('Failed to start location tracking: $e');
    }
  }

  // Stop location tracking
  Future<void> stopTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    _statusController.add('Location tracking stopped.');
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
    } catch (e) {
      _statusController.add('Failed to update location to backend: $e');
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