import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/location.dart';
import '../models/alert.dart';

class ApiService {
  // Local backend URL - Make sure your backend server is running on localhost:8000
  static const String baseUrl = 'http://localhost:8000';
  
  final http.Client _client = http.Client();

  // Tourist Registration - matches backend POST /tourists/register
  Future<Map<String, dynamic>> registerTourist({
    required String name,
    required String contact,
    String? emergencyContact,
    String? tripInfo,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/tourists/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'contact': contact,
          'emergency_contact': emergencyContact ?? contact,
          'trip_info': tripInfo,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Tourist registered successfully',
          'tourist': data,
        };
      } else {
        throw Exception('Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      // Better error handling for connection issues
      if (e.toString().contains('Failed to connect') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Could not connect')) {
        throw Exception('❌ Backend server not running!\n\nPlease start your backend server:\n1. Open terminal\n2. Navigate to backend folder\n3. Run: python app.py\n\nThen try again.');
      }
      throw Exception('Failed to register tourist: $e');
    }
  }

  // Update Location - matches backend POST /locations/update
  Future<Map<String, dynamic>> updateLocation({
    required int touristId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/locations/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tourist_id': touristId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Location updated successfully',
          'location': data,
        };
      } else {
        throw Exception('Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      // Better error handling for connection issues
      if (e.toString().contains('Failed to connect') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Could not connect')) {
        throw Exception('❌ Backend server not running!\n\nPlease start your backend server first.');
      }
      throw Exception('Failed to update location: $e');
    }
  }

  // Get All Locations - matches backend GET /locations/all
  Future<List<Map<String, dynamic>>> getAllLocations() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/locations/all'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (e) {
      throw Exception('Failed to load locations: $e');
    }
  }

  // Get Heatmap Data - create from locations
  Future<List<HeatmapPoint>> getHeatmapData() async {
    try {
      // Get all locations and convert to heatmap points
      final locations = await getAllLocations();
      if (locations.isEmpty) {
        return []; // Return empty list if no location data from backend
      }
      
      return locations.map((location) {
        final intensity = location['intensity']?.toDouble();
        final latitude = location['latitude']?.toDouble();
        final longitude = location['longitude']?.toDouble();
        
        if (intensity == null || latitude == null || longitude == null) {
          throw Exception('Location data missing required values from backend');
        }
        
        return HeatmapPoint(
          latitude: latitude,
          longitude: longitude,
          intensity: intensity,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get heatmap data: $e');
    }
  }

  // Panic Alert - matches backend POST /alerts/panic
  Future<Map<String, dynamic>> sendPanicAlert({
    required int touristId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/alerts/panic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tourist_id': touristId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Emergency alert sent successfully!',
          'alert': data,
        };
      } else {
        throw Exception('Failed to send panic alert: ${response.statusCode}');
      }
    } catch (e) {
      // Better error handling for connection issues
      if (e.toString().contains('Failed to connect') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Could not connect')) {
        throw Exception('❌ Backend server not running!\n\nPlease start your backend server first.');
      }
      throw Exception('Failed to send panic alert: $e');
    }
  }

  // Get Tourist Details - matches backend GET /tourists/{tourist_id}
  Future<Map<String, dynamic>> getTourist(int touristId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/tourists/$touristId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get tourist details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get tourist details: $e');
    }
  }

  // Get Restricted Zones - fetches from backend endpoint /zones/restricted
  Future<List<RestrictedZone>> getRestrictedZones() async {
    try {
      // Attempt to get zones from backend first
      final response = await _client.get(
        Uri.parse('$baseUrl/zones/restricted'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) {
          return RestrictedZone(
            id: item['id'].toString(),
            name: item['name'],
            description: item['description'] ?? '',
            polygonCoordinates: (item['polygon_coordinates'] as List)
                .map((coord) => LatLng(coord['lat'], coord['lng']))
                .toList(),
            type: _parseZoneType(item['type']),
            warningMessage: item['warning_message'] ?? 'You are entering a restricted area.',
          );
        }).toList();
      } else {
        // If backend doesn't have this endpoint yet, return empty list
        return [];
      }
    } catch (e) {
      // If backend is not available or endpoint doesn't exist, return empty list
      // This prevents the app from crashing when backend doesn't support geo-fencing yet
      return [];
    }
  }

  ZoneType _parseZoneType(String type) {
    switch (type.toLowerCase()) {
      case 'high_risk':
        return ZoneType.highRisk;
      case 'dangerous':
        return ZoneType.dangerous;
      case 'restricted':
        return ZoneType.restricted;
      case 'caution':
        return ZoneType.caution;
      default:
        return ZoneType.caution;
    }
  }

  // Location Search using OpenStreetMap Nominatim API
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await _client.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=5'),
        headers: {'User-Agent': 'TouristSafetyApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          'display_name': item['display_name'],
          'lat': double.parse(item['lat']),
          'lon': double.parse(item['lon']),
        }).toList();
      } else {
        throw Exception('Search failed');
      }
    } catch (e) {
      throw Exception('Failed to search location: $e');
    }
  }

  // Get Safety Score - using tourist details from backend  
  Future<SafetyScore> getSafetyScore(int touristId) async {
    try {
      final tourist = await getTourist(touristId);
      final score = tourist['safety_score']?.toInt();
      
      if (score == null) {
        throw Exception('Safety score not available from backend');
      }
      
      return SafetyScore(
        touristId: touristId.toString(),
        score: score,
        level: score >= 80 ? 'Safe' : score >= 60 ? 'Medium' : 'Risk',
        description: score >= 80 
            ? 'You are in a safe area'
            : score >= 60 
                ? 'Moderate safety level'
                : 'High risk area - be cautious',
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to get safety score: $e');
    }
  }

  // Get Alerts - matches backend GET /alerts, filtered by tourist ID
  Future<List<Alert>> getAlerts([int? touristId]) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/alerts'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Filter alerts by tourist ID if provided
        List<dynamic> filteredData = data;
        if (touristId != null) {
          filteredData = data.where((item) => item['tourist_id'] == touristId).toList();
        }
        
        return filteredData.map((item) {
          return Alert(
            id: item['id'].toString(),
            touristId: item['tourist_id'].toString(),
            type: item['type'] == 'panic' ? AlertType.emergency : AlertType.general,
            title: item['type'] == 'panic' ? 'Emergency Alert' : 'Geofence Alert',
            message: item['message'] ?? '',
            timestamp: DateTime.parse(item['timestamp']),
            severity: item['type'] == 'panic' ? AlertSeverity.high : AlertSeverity.medium,
            isRead: item['status'] == 'resolved',
          );
        }).toList();
      } else {
        throw Exception('Failed to load alerts');
      }
    } catch (e) {
      throw Exception('Failed to get alerts: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}