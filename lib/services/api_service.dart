import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/location.dart';
import '../models/alert.dart';

class ApiService {
  // Mock API base URL - replace with your actual backend URL
  static const String baseUrl = 'https://api.example.com';
  
  // For development/demo purposes, we'll use mock responses
  static const bool useMockApi = true;
  
  final http.Client _client = http.Client();

  // Tourist Registration
  Future<Map<String, dynamic>> registerTourist({
    required String name,
    required String touristId,
    String? email,
    String? phone,
  }) async {
    if (useMockApi) {
      // Mock successful registration
      await Future.delayed(const Duration(seconds: 1));
      return {
        'success': true,
        'message': 'Tourist registered successfully',
        'tourist': {
          'tourist_id': touristId,
          'name': name,
          'email': email,
          'phone': phone,
          'registration_date': DateTime.now().toIso8601String(),
        }
      };
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/registerTourist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'tourist_id': touristId,
          'email': email,
          'phone': phone,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Failed to register tourist: $e');
    }
  }

  // Update Location
  Future<Map<String, dynamic>> updateLocation(LocationData location) async {
    if (useMockApi) {
      // Mock successful location update
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'message': 'Location updated successfully',
      };
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/updateLocation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(location.toJson()),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  // Get Heatmap Data
  Future<List<HeatmapPoint>> getHeatmapData() async {
    if (useMockApi) {
      // Mock heatmap data
      await Future.delayed(const Duration(milliseconds: 800));
      return [
        HeatmapPoint(latitude: 28.6139, longitude: 77.2090, intensity: 0.8),
        HeatmapPoint(latitude: 28.6129, longitude: 77.2080, intensity: 0.6),
        HeatmapPoint(latitude: 28.6149, longitude: 77.2100, intensity: 0.9),
        HeatmapPoint(latitude: 28.6159, longitude: 77.2110, intensity: 0.4),
        HeatmapPoint(latitude: 28.6169, longitude: 77.2120, intensity: 0.7),
      ];
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/heatmap'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => HeatmapPoint.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load heatmap data');
      }
    } catch (e) {
      throw Exception('Failed to get heatmap data: $e');
    }
  }

  // Get Restricted Zones
  Future<List<RestrictedZone>> getRestrictedZones() async {
    if (useMockApi) {
      // Mock restricted zones data
      await Future.delayed(const Duration(milliseconds: 600));
      return [
        RestrictedZone(
          id: '1',
          name: 'High Crime Area',
          description: 'Area with increased crime activity',
          type: ZoneType.highRisk,
          warningMessage: '⚠ You have entered a high-risk area. Please be cautious.',
          polygonCoordinates: [
            const LatLng(28.6100, 77.2050),
            const LatLng(28.6120, 77.2050),
            const LatLng(28.6120, 77.2080),
            const LatLng(28.6100, 77.2080),
          ],
        ),
        RestrictedZone(
          id: '2',
          name: 'Construction Zone',
          description: 'Active construction area',
          type: ZoneType.restricted,
          warningMessage: '⚠ Construction zone ahead. Access may be restricted.',
          polygonCoordinates: [
            const LatLng(28.6150, 77.2100),
            const LatLng(28.6170, 77.2100),
            const LatLng(28.6170, 77.2130),
            const LatLng(28.6150, 77.2130),
          ],
        ),
      ];
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/restrictedZones'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => RestrictedZone.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load restricted zones');
      }
    } catch (e) {
      throw Exception('Failed to get restricted zones: $e');
    }
  }

  // Send Panic Alert
  Future<Map<String, dynamic>> sendPanicAlert(PanicAlert panicAlert) async {
    if (useMockApi) {
      // Mock panic alert response
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'success': true,
        'message': 'Panic alert sent successfully. Help is on the way!',
        'alert_id': 'panic_${DateTime.now().millisecondsSinceEpoch}',
      };
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/panic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(panicAlert.toJson()),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Failed to send panic alert: $e');
    }
  }

  // Get Safety Score
  Future<SafetyScore> getSafetyScore(String touristId) async {
    if (useMockApi) {
      // Mock safety score - simulate different scores based on time
      await Future.delayed(const Duration(milliseconds: 400));
      final score = (DateTime.now().millisecondsSinceEpoch % 100);
      return SafetyScore(
        touristId: touristId,
        score: score > 20 ? score : score + 60, // Ensure minimum score of 60
        level: score >= 80 ? 'Safe' : score >= 60 ? 'Medium' : 'Risk',
        description: score >= 80 
            ? 'You are in a safe area'
            : score >= 60 
                ? 'Moderate safety level'
                : 'High risk area - be cautious',
        updatedAt: DateTime.now(),
      );
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/safetyScore/$touristId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return SafetyScore.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load safety score');
      }
    } catch (e) {
      throw Exception('Failed to get safety score: $e');
    }
  }

  // Search Location (using Nominatim OpenStreetMap)
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    try {
      final response = await _client.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5'),
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
        throw Exception('Failed to search location');
      }
    } catch (e) {
      throw Exception('Failed to search location: $e');
    }
  }

  // Get Alerts
  Future<List<Alert>> getAlerts(String touristId) async {
    if (useMockApi) {
      await Future.delayed(const Duration(milliseconds: 500));
      return [
        Alert(
          id: '1',
          touristId: touristId,
          type: AlertType.safety,
          title: 'Safety Advisory',
          message: 'Weather conditions may affect visibility in your area.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          severity: AlertSeverity.medium,
        ),
        Alert(
          id: '2',
          touristId: touristId,
          type: AlertType.general,
          title: 'Welcome!',
          message: 'Welcome to the Tourist Safety App. Stay safe and enjoy your trip!',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          severity: AlertSeverity.low,
          isRead: true,
        ),
      ];
    }

    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/alerts/$touristId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Alert.fromJson(item)).toList();
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