import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";

import "../models/location.dart";
import "../models/alert.dart";

class ApiService {
  static const String baseUrl = "http://159.89.166.91:8000";
  static const Duration timeout = Duration(seconds: 15);
  
  final http.Client client = http.Client();

  Map<String, String> get headers => {"Content-Type": "application/json"};

  Future<bool> testConnectivity() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl/alerts"),
        headers: headers,
      ).timeout(timeout);
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint("API connectivity failed: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> registerTourist({
    required String name,
    required String contact,
    String? emergencyContact,
    String? tripInfo,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl/tourists/register"),
        headers: headers,
        body: jsonEncode({
          "name": name,
          "contact": contact,
          "emergency_contact": emergencyContact ?? contact,
          "trip_info": tripInfo,
        }),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "message": "Tourist registered successfully",
          "tourist": data,
        };
      }

      throw HttpException("Registration failed: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Registration error: $e");
      return {
        "success": false,
        "message": "Registration failed. Please check your connection.",
      };
    }
  }

  void dispose() {
    client.close();
  }

  Future<Map<String, dynamic>> updateLocation({
    required int touristId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl/locations/update"),
        headers: headers,
        body: jsonEncode({
          "tourist_id": touristId,
          "latitude": latitude,
          "longitude": longitude,
        }),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "message": "Location updated successfully",
          "location": data,
        };
      }

      throw HttpException("Failed to update location: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Location update error: $e");
      throw Exception("Failed to update location: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl/locations/all"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      throw HttpException("Failed to load locations: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Get locations error: $e");
      throw Exception("Failed to load locations: $e");
    }
  }

  Future<List<HeatmapPoint>> getHeatmapData() async {
    try {
      final locations = await getAllLocations();
      return locations.map((location) {
        final intensity = location["intensity"]?.toDouble() ?? 0.5;
        final latitude = location["latitude"]?.toDouble();
        final longitude = location["longitude"]?.toDouble();
        
        if (latitude == null || longitude == null) {
          throw Exception("Location data missing coordinates");
        }
        
        return HeatmapPoint(
          latitude: latitude,
          longitude: longitude,
          intensity: intensity,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint("Heatmap data error: $e");
      throw Exception("Failed to get heatmap data: $e");
    }
  }

  Future<Map<String, dynamic>> sendPanicAlert({
    required int touristId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl/alerts/panic"),
        headers: headers,
        body: jsonEncode({
          "tourist_id": touristId,
          "latitude": latitude,
          "longitude": longitude,
        }),
      ).timeout(timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "message": "Emergency alert sent successfully!",
          "alert": data,
        };
      }

      throw HttpException("Failed to send panic alert: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Panic alert error: $e");
      throw Exception("Failed to send panic alert: $e");
    }
  }

  Future<Map<String, dynamic>> getTourist(int touristId) async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl/tourists/$touristId"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw HttpException("Failed to get tourist details: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Get tourist error: $e");
      throw Exception("Failed to get tourist details: $e");
    }
  }

  Future<List<RestrictedZone>> getRestrictedZones() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl/zones/restricted"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) {
          return RestrictedZone(
            id: item["id"].toString(),
            name: item["name"],
            description: item["description"] ?? "",
            polygonCoordinates: (item["polygon_coordinates"] as List)
                .map((coord) => LatLng(coord["lat"], coord["lng"]))
                .toList(),
            type: _parseZoneType(item["type"]),
            warningMessage: item["warning_message"] ?? "You are entering a restricted area.",
          );
        }).toList();
      }

      throw HttpException("Failed to load restricted zones: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Get restricted zones error: $e");
      throw Exception("Failed to get restricted zones: $e");
    }
  }

  ZoneType _parseZoneType(String type) {
    switch (type.toLowerCase()) {
      case "high_risk":
        return ZoneType.highRisk;
      case "dangerous":
        return ZoneType.dangerous;
      case "restricted":
        return ZoneType.restricted;
      case "caution":
        return ZoneType.caution;
      default:
        return ZoneType.caution;
    }
  }

  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await client.get(
        Uri.parse("https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=5"),
        headers: {"User-Agent": "TouristSafetyApp/1.0"},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          "display_name": item["display_name"],
          "lat": double.parse(item["lat"]),
          "lon": double.parse(item["lon"]),
        }).toList();
      }

      throw HttpException("Search failed: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Location search error: $e");
      return [];
    }
  }

  Future<SafetyScore> getSafetyScore(int touristId) async {
    try {
      final tourist = await getTourist(touristId);
      final score = tourist["safety_score"]?.toInt() ?? 50;
      
      return SafetyScore(
        touristId: touristId.toString(),
        score: score,
        level: score >= 80 ? "Safe" : score >= 60 ? "Medium" : "Risk",
        description: score >= 80 
            ? "You are in a safe area"
            : score >= 60 
                ? "Moderate safety level"
                : "High risk area - be cautious",
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Get safety score error: $e");
      return SafetyScore(
        touristId: touristId.toString(),
        score: 50,
        level: "Medium",
        description: "Safety score unavailable",
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<List<Alert>> getAlerts([int? touristId]) async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl/alerts"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        List<dynamic> filteredData = data;
        if (touristId != null) {
          filteredData = data.where((item) => item["tourist_id"] == touristId).toList();
        }
        
        return filteredData.map((item) {
          return Alert(
            id: item["id"].toString(),
            touristId: item["tourist_id"].toString(),
            type: _parseAlertType(item["type"]),
            title: item["title"] ?? "Alert",
            message: item["message"],
            latitude: item["latitude"]?.toDouble(),
            longitude: item["longitude"]?.toDouble(),
            timestamp: DateTime.tryParse(item["timestamp"]) ?? DateTime.now(),
            isRead: item["is_read"] ?? false,
          );
        }).toList();
      }

      throw HttpException("Failed to get alerts: ${response.statusCode}");
    } catch (e) {
      if (kDebugMode) debugPrint("Get alerts error: $e");
      return [];
    }
  }

  AlertType _parseAlertType(String type) {
    switch (type.toLowerCase()) {
      case "panic":
      case "emergency":
        return AlertType.panic;
      case "zone_entry":
      case "geofence":
        return AlertType.geoFence;
      case "safety":
        return AlertType.safety;
      case "general":
        return AlertType.general;
      default:
        return AlertType.general;
    }
  }
}
