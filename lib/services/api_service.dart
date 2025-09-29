import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_dotenv/flutter_dotenv.dart";

import "../models/geospatial_heat.dart";
import "../models/alert.dart";

class ApiService {
  // Load configuration from .env file - required values
  static String get baseUrl => dotenv.env['API_BASE_URL']!;
  static String get apiPrefix => dotenv.env['API_PREFIX']!;
  static Duration get timeout => Duration(seconds: int.parse(dotenv.env['REQUEST_TIMEOUT_SECONDS']!));
  static bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  
  final http.Client client = http.Client();
  String? _authToken;

  Map<String, String> get headers {
    final Map<String, String> baseHeaders = {"Content-Type": "application/json"};
    if (_authToken != null) {
      baseHeaders["Authorization"] = "Bearer $_authToken";
    }
    return baseHeaders;
  }

  // Initialize authentication token from storage
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');

    } catch (e) {
      if (debugMode) debugPrint("Failed to load auth token: $e");
    }
  }

  // Save authentication token to storage
  Future<void> _saveAuthToken(String token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (e) {
      if (debugMode) debugPrint("Failed to save auth token: $e");
    }
  }

  // Clear authentication token
  Future<void> clearAuth() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      if (debugMode) debugPrint("Failed to clear auth token: $e");
    }
  }

  // Test server connectivity
  Future<bool> testConnection() async {
    try {
      if (debugMode) debugPrint("Testing connection to: $baseUrl");
      
      final response = await client.get(
        Uri.parse("$baseUrl/health"),
        headers: {"Content-Type": "application/json"},
      ).timeout(Duration(seconds: 5));

      if (debugMode) debugPrint("Connection test result: ${response.statusCode}");
      return response.statusCode == 200 || response.statusCode == 404; // 404 is ok, means server is running
    } catch (e) {
      if (debugMode) debugPrint("Connection test failed: $e");
      return false;
    }
  }

  // Debug token validation endpoint
  Future<Map<String, dynamic>> debugToken() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/auth/debug-token"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (debugMode) {
          debugPrint("Token debug info: $data");
        }
        return {
          "success": true,
          "token_info": data,
        };
      }

      throw HttpException("Token validation failed: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Token debug error: $e");
      return {
        "success": false,
        "message": "Token validation failed",
      };
    }
  }



  // Authentication endpoints
  Future<Map<String, dynamic>> registerTourist({
    required String email,
    required String password,
    String? name,
    String? phone,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          if (name != null) "name": name,
          if (phone != null) "phone": phone,
          if (emergencyContact != null) "emergency_contact": emergencyContact,
          if (emergencyPhone != null) "emergency_phone": emergencyPhone,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "message": data["message"] ?? "Registration successful",
          "user_id": data["user_id"],
          "email": data["email"],
        };
      }

      final errorData = jsonDecode(response.body);
      throw HttpException("Registration failed: ${errorData['detail'] ?? errorData['message'] ?? 'Unknown error'}");
    } catch (e) {
      if (debugMode) debugPrint("Registration error: $e");
      return {
        "success": false,
        "message": e is HttpException ? e.message : "Registration failed. Please check your connection.",
      };
    }
  }

  Future<Map<String, dynamic>> loginTourist({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["access_token"];
        
        // Validate token format and length
        if (token == null || token.isEmpty) {
          throw HttpException("Invalid token received from server");
        }
        
        // Log token info for debugging (first/last 10 chars only)
        if (debugMode) {
          final tokenPreview = token.length > 20 
              ? "${token.substring(0, 10)}...${token.substring(token.length - 10)}" 
              : token;
          debugPrint("Login successful. Token preview: $tokenPreview (length: ${token.length})");
        }
        
        await _saveAuthToken(token);
        return {
          "success": true,
          "access_token": token,
          "token_type": data["token_type"] ?? "bearer",
          "user_id": data["user_id"],
          "email": data["email"],
          "role": data["role"] ?? "tourist",
          "token_length": token.length, // For debugging
        };
      }

      final errorData = jsonDecode(response.body);
      throw HttpException("Login failed: ${errorData['detail'] ?? errorData['message'] ?? 'Invalid credentials'}");
    } catch (e) {
      if (debugMode) debugPrint("Login error: $e");
      return {
        "success": false,
        "message": e is HttpException ? e.message : "Login failed. Please check your connection.",
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/auth/me"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "user": data,
        };
      } else if (response.statusCode == 403) {
        // Token might be corrupted or invalid
        if (debugMode) {
          debugPrint("403 Forbidden - Token might be corrupted. Current token: ${_authToken?.substring(0, 20)}...");
        }
        
        // Try debug token endpoint to verify token issues
        final debugResult = await debugToken();
        if (debugMode) {
          debugPrint("Debug token result: $debugResult");
        }
        
        throw HttpException("Authentication failed. Please login again. (Token may be corrupted)");
      } else if (response.statusCode == 401) {
        throw HttpException("Authentication expired. Please login again.");
      }

      throw HttpException("Failed to get user profile: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Get user error: $e");
      return {
        "success": false,
        "message": e is HttpException ? e.message : "Failed to load user profile.",
      };
    }
  }

  // Location tracking endpoints
  Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lon,
    double? speed,
    double? altitude,
    double? accuracy,
    DateTime? timestamp,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/location/update"),
        headers: headers,
        body: jsonEncode({
          "lat": lat,
          "lon": lon,
          if (speed != null) "speed": speed,
          if (altitude != null) "altitude": altitude,
          if (accuracy != null) "accuracy": accuracy,
          if (timestamp != null) "timestamp": timestamp.toIso8601String(),
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "status": data["status"],
          "location_id": data["location_id"],
          "safety_score": data["safety_score"],
          "risk_level": data["risk_level"],
          "lat": data["lat"],
          "lon": data["lon"],
          "timestamp": data["timestamp"],
        };
      }

      throw HttpException("Failed to update location: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Location update error: $e");
      return {
        "success": false,
        "message": "Failed to update location. Please check your connection.",
      };
    }
  }

  Future<Map<String, dynamic>> getLocationHistory({int limit = 100}) async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/location/history?limit=$limit"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return {
          "success": true,
          "locations": data,
        };
      }

      throw HttpException("Failed to load location history: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Get location history error: $e");
      return {
        "success": false,
        "message": "Failed to load location history.",
      };
    }
  }

  // Trip management endpoints
  Future<Map<String, dynamic>> startTrip({
    required String destination,
    String? itinerary,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/trip/start"),
        headers: headers,
        body: jsonEncode({
          "destination": destination,
          if (itinerary != null) "itinerary": itinerary,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "trip_id": data["trip_id"],
          "destination": data["destination"],
          "status": data["status"],
          "start_date": data["start_date"],
        };
      }

      throw HttpException("Failed to start trip: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Start trip error: $e");
      return {
        "success": false,
        "message": "Failed to start trip.",
      };
    }
  }

  Future<Map<String, dynamic>> endTrip() async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/trip/end"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "trip_id": data["trip_id"],
          "status": data["status"],
          "end_date": data["end_date"],
        };
      }

      throw HttpException("Failed to end trip: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("End trip error: $e");
      return {
        "success": false,
        "message": "Failed to end trip.",
      };
    }
  }

  Future<Map<String, dynamic>> getTripHistory() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/trip/history"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return {
          "success": true,
          "trips": data,
        };
      }

      throw HttpException("Failed to load trip history: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Get trip history error: $e");
      return {
        "success": false,
        "message": "Failed to load trip history.",
      };
    }
  }

  // Safety and emergency endpoints
  Future<Map<String, dynamic>> getSafetyScore() async {
    try {
      if (debugMode) debugPrint("Requesting safety score from: $baseUrl$apiPrefix/safety/score");
      
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/safety/score"),
        headers: headers,
      ).timeout(timeout);

      if (debugMode) debugPrint("Safety score response status: ${response.statusCode}");
      if (debugMode) debugPrint("Safety score response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "safety_score": data["safety_score"],
          "risk_level": data["risk_level"],
          "last_updated": data["last_updated"],
        };
      } else if (response.statusCode == 401) {
        if (debugMode) debugPrint("Authentication error: ${response.body}");
        return {
          "success": false,
          "message": "Authentication required. Please login again.",
          "auth_error": true,
        };
      } else if (response.statusCode == 403) {
        if (debugMode) debugPrint("Access forbidden: ${response.body}");
        return {
          "success": false,
          "message": "Access denied. Invalid token or permissions.",
          "auth_error": true,
        };
      }

      throw HttpException("Failed to get safety score: ${response.statusCode} - ${response.body}");
    } catch (e) {
      if (debugMode) debugPrint("Get safety score error: $e");
      return {
        "success": false,
        "message": "Failed to get safety score: ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> triggerSOS() async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/sos/trigger"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "status": data["status"],
          "alert_id": data["alert_id"],
          "notifications_sent": data["notifications_sent"],
          "timestamp": data["timestamp"],
        };
      }

      throw HttpException("Failed to trigger SOS: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("SOS trigger error: $e");
      return {
        "success": false,
        "message": "Failed to send SOS alert. Please try again.",
      };
    }
  }

  // Search functionality
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // Using Nominatim for location search as per specifications
      final encodedQuery = Uri.encodeComponent(query);
      final response = await client.get(
        Uri.parse("https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=10"),
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
      if (debugMode) debugPrint("Location search error: $e");
      return [];
    }
  }

  // Geofencing and zone management
  Future<Map<String, dynamic>> checkGeofence({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/ai/geofence/check"),
        headers: headers,
        body: jsonEncode({
          "lat": lat,
          "lon": lon,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "status": data["status"], // "safe", "risky", "restricted"
          "zone_name": data["zone_name"],
          "distance_to_zone": data["distance_to_zone"],
          "recommendations": data["recommendations"],
        };
      }

      throw HttpException("Failed to check geofence: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Geofence check error: $e");
      return {
        "success": false,
        "status": "safe",
        "zone_name": null,
        "distance_to_zone": 0.0,
        "recommendations": [],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getSafetyZones() async {
    try {
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/zones/list"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      throw HttpException("Failed to load safety zones: ${response.statusCode}");
    } catch (e) {
      if (debugMode) debugPrint("Get safety zones error: $e");
      return [];
    }
  }

  // Heatmap and analytics data
  Future<List<GeospatialHeatPoint>> getPanicAlertHeatData({
    int? daysPast = 30,
    double? minLat,
    double? maxLat, 
    double? minLng,
    double? maxLng,
  }) async {
    try {
      // Get recent alerts to generate heatmap data
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/alerts/recent?limit=1000&severity=high"),
        headers: headers,
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Filter for SOS/panic alerts and recent data
        final panicAlerts = data.where((item) {
          if (item["type"]?.toLowerCase() != "sos") return false;
          
          // Check date filter
          if (daysPast != null) {
            final timestamp = DateTime.tryParse(item["created_at"] ?? "");
            if (timestamp == null || 
                timestamp.isBefore(DateTime.now().subtract(Duration(days: daysPast)))) {
              return false;
            }
          }
          
          // Check location bounds
          final location = item["location"];
          if (location == null) return false;
          final lat = location["lat"]?.toDouble();
          final lng = location["lon"]?.toDouble();
          if (lat == null || lng == null) return false;
          
          if (minLat != null && lat < minLat) return false;
          if (maxLat != null && lat > maxLat) return false;
          if (minLng != null && lng < minLng) return false;
          if (maxLng != null && lng > maxLng) return false;
          
          return true;
        }).toList();

        return _aggregatePanicAlertsFromBackend(panicAlerts);
      }

      if (debugMode) debugPrint("Panic alert API failed with status: ${response.statusCode}");
      return [];
    } catch (e) {
      if (debugMode) debugPrint("Panic alert heat data error: $e");
      return [];
    }
  }

  /// Aggregate panic alerts from backend database into heat points
  List<GeospatialHeatPoint> _aggregatePanicAlertsFromBackend(List<dynamic> data) {
    final Map<String, List<Map<String, dynamic>>> locationGroups = {};
    
    // Group alerts by approximate location (100m grid)
    for (final item in data) {
      final location = item["location"];
      final lat = (location["lat"] as num).toDouble();
      final lng = (location["lon"] as num).toDouble();
      
      // Create location grid key (approx 100m precision)
      final gridKey = "${(lat * 1000).round()},${(lng * 1000).round()}";
      locationGroups[gridKey] ??= [];
      locationGroups[gridKey]!.add({
        'latitude': lat,
        'longitude': lng,
        'timestamp': item["created_at"],
        'tourist_id': item["tourist_id"],
        'description': item["description"],
      });
    }

    return locationGroups.entries.map((entry) {
      final alerts = entry.value;
      final firstAlert = alerts.first;
      
      // Calculate average position
      final avgLat = alerts.map((a) => a["latitude"] as double).reduce((a, b) => a + b) / alerts.length;
      final avgLng = alerts.map((a) => a["longitude"] as double).reduce((a, b) => a + b) / alerts.length;
      
      // Calculate intensity based on alert count and recency
      final alertCount = alerts.length;
      final recentCount = alerts.where((alert) {
        final timestamp = DateTime.tryParse(alert["timestamp"] ?? "");
        return timestamp?.isAfter(DateTime.now().subtract(const Duration(days: 7))) ?? false;
      }).length;
      
      // Intensity formula: base on count + recent activity boost
      final intensity = ((alertCount / 10.0) + (recentCount / 5.0)).clamp(0.1, 1.0);
      
      return GeospatialHeatPoint.fromPanicAlert(
        latitude: avgLat,
        longitude: avgLng,
        intensity: intensity,
        alertCount: alertCount,
        description: alertCount == 1 
            ? "1 emergency alert"
            : "$alertCount emergency alerts",
        timestamp: DateTime.tryParse(firstAlert["timestamp"] ?? "") ?? DateTime.now(),
      );
    }).toList();
  }

  // Additional missing methods for compatibility
  Future<List<RestrictedZone>> getRestrictedZones() async {
    try {
      final response = await getSafetyZones();
      return response.map<RestrictedZone>((item) => RestrictedZone.fromJson(item)).toList();
    } catch (e) {
      if (debugMode) debugPrint("Get restricted zones error: $e");
      return [];
    }
  }

  Future<List<Alert>> getAlerts([int? touristId]) async {
    // This method is not available for tourists in the new API
    // Only police/authority users can view alerts
    return [];
  }

  Future<bool> markAlertAsRead(String alertId) async {
    // This method is not available for tourists in the new API
    return false;
  }

  Future<bool> deleteAlert(String alertId) async {
    // This method is not available for tourists in the new API
    return false;
  }

  Future<Map<String, dynamic>> sendPanicAlert({
    required int touristId,
    required double latitude,
    required double longitude,
  }) async {
    // Use the new SOS endpoint instead
    return await triggerSOS();
  }

  void dispose() {
    client.close();
  }
}
