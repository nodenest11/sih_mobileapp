import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

class LocationService {
  StreamController<LocationData>? _locationController;
  Timer? _locationTimer;
  
  Stream<LocationData> get locationStream => _locationController!.stream;

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }
    return true;
  }

  Future<LocationData> getCurrentLocation() async {
    await _handleLocationPermission();
    
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
    );
  }

  Future<void> startLocationTracking() async {
    await _handleLocationPermission();
    
    _locationController = StreamController<LocationData>.broadcast();
    
    // Update location every 10 seconds as specified
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        LocationData location = await getCurrentLocation();
        _locationController?.add(location);
      } catch (e) {
        print('Error getting location: $e');
      }
    });
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationController?.close();
    _locationTimer = null;
    _locationController = null;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  bool isPointInPolygon(double lat, double lon, List<List<double>> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      double xi = polygon[i][0];
      double yi = polygon[i][1];
      double xj = polygon[j][0];
      double yj = polygon[j][1];
      
      if (((yi > lon) != (yj > lon)) && (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void dispose() {
    stopLocationTracking();
  }
}