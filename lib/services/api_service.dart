import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';
import '../models/alert.dart';

class ApiService {
  // Get API configuration from environment variables
  static String get baseUrl => dotenv.env['BASE_URL']!;
  static Duration get timeout => Duration(seconds: int.parse(dotenv.env['API_TIMEOUT']!));
  static String get nominatimUrl => dotenv.env['NOMINATIM_URL']!;
  
  // Common headers for all requests
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> registerTourist(String name, String touristId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tourists/register'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'contact': touristId, // Using tourist_id as contact for simplicity
          'trip_info': 'Mobile app registration',
          'emergency_contact': touristId,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to register tourist: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error during registration: $e');
    }
  }

  Future<bool> updateLocation(String touristId, double lat, double lon) async {
    try {
      // Validate tourist ID is numeric
      final numericTouristId = int.parse(touristId);
      
      final response = await http.post(
        Uri.parse('$baseUrl/locations/update'),
        headers: headers,
        body: jsonEncode({
          'tourist_id': numericTouristId,
          'latitude': lat,
          'longitude': lon,
        }),
      ).timeout(timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Invalid tourist ID format: Tourist ID must be numeric');
      }
      throw Exception('Failed to update location: $e');
    }
  }

  Future<HeatmapResponse> getHeatmapData({
    int hours = 24,
    bool includeAlerts = true,
    double gridSize = 0.005,
  }) async {
    try {
      // Build query parameters
      final queryParams = {
        'hours': hours.toString(),
        'include_alerts': includeAlerts.toString(),
        'grid_size': gridSize.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/locations/heatmap').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        return HeatmapResponse.fromJson(data);
      } else {
        throw Exception('Failed to get heatmap data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch heatmap data: $e');
    }
  }

  Future<List<RestrictedZone>> getRestrictedZones() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/restrictedZones'),
        headers: headers,
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => RestrictedZone.fromJson(item)).toList();
      } else if (response.statusCode == 404) {
        // Endpoint not implemented yet, return empty list
        return [];
      } else {
        throw Exception('Failed to get restricted zones: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // For now, return empty list if endpoint doesn't exist
      if (e.toString().contains('404')) {
        return [];
      }
      throw Exception('Failed to fetch restricted zones: $e');
    }
  }

  Future<bool> sendPanicAlert(String touristId, double lat, double lon) async {
    try {
      // Validate tourist ID is numeric
      final numericTouristId = int.parse(touristId);
      
      final response = await http.post(
        Uri.parse('$baseUrl/alerts/panic'),
        headers: headers,
        body: jsonEncode({
          'tourist_id': numericTouristId,
          'latitude': lat,
          'longitude': lon,
        }),
      ).timeout(timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Invalid tourist ID format: Tourist ID must be numeric');
      }
      throw Exception('Failed to send panic alert: $e');
    }
  }

  Future<SafetyScore> getSafetyScore(String touristId) async {
    try {
      // Validate tourist ID is numeric for the URL
      final numericTouristId = int.parse(touristId);
      
      final response = await http.get(
        Uri.parse('$baseUrl/admin/$numericTouristId/risk-assessment'),
        headers: headers,
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        // Convert risk assessment to safety score format
        return SafetyScore(
          score: data['safety_score'] ?? 100,
          level: data['risk_level'] ?? 'low',
          lastUpdate: DateTime.now(),
        );
      } else {
        throw Exception('Failed to get safety score: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Invalid tourist ID format: Tourist ID must be numeric');
      }
      throw Exception('Failed to fetch safety score: $e');
    }
  }

  Future<Map<String, dynamic>?> searchLocation(String query) async {
    // Using Nominatim API for location search (free OpenStreetMap service)
    try {
      final response = await http.get(
        Uri.parse('$nominatimUrl/search?format=json&q=$query&limit=1'),
        headers: {'User-Agent': 'TouristSafetyApp/1.0'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lon': double.parse(data[0]['lon']),
            'display_name': data[0]['display_name'],
          };
        }
      } else {
        throw Exception('Location search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search location: $e');
    }
    return null;
  }
}