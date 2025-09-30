import "dart:convert";
import "dart:io";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_dotenv/flutter_dotenv.dart";

import "../models/geospatial_heat.dart";
import "../models/alert.dart";
import "../utils/logger.dart";

class ApiService {
  // Singleton pattern to ensure only one instance throughout the app
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Load configuration from .env file - required values
  static String get baseUrl => dotenv.env['API_BASE_URL']!;
  static String get apiPrefix => dotenv.env['API_PREFIX']!;
  static Duration get timeout => Duration(seconds: int.parse(dotenv.env['REQUEST_TIMEOUT_SECONDS']!));
  static bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  
  final http.Client client = http.Client();
  String? _authToken;
  bool _isInitialized = false;

  Map<String, String> get headers {
    final Map<String, String> baseHeaders = {"Content-Type": "application/json"};
    if (_authToken != null && _authToken!.isNotEmpty) {
      baseHeaders["Authorization"] = "Bearer $_authToken";
    }
    return baseHeaders;
  }

  // Safer headers that ensure auth initialization
  Future<Map<String, String>> get safeHeaders async {
    await _ensureInitialized();
    final Map<String, String> baseHeaders = {"Content-Type": "application/json"};
    if (_authToken != null && _authToken!.isNotEmpty) {
      baseHeaders["Authorization"] = "Bearer $_authToken";
    }
    return baseHeaders;
  }

  // Helper to mask passwords for safe logging (never log plaintext)
  String _maskPassword(String password) {
    final masked = List.filled(password.length, '*').join();
    return '$masked (${password.length} chars)';
  }

  // Helper to mask tokens for safe logging (show first/last 6 chars)
  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 12) return '*' * token.length;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)} (${token.length} chars)';
  }

  // Enhanced request logging with masked token
  void _logRequest(String method, String endpoint, {Map<String, String>? headers}) {
    AppLogger.apiRequest(method, endpoint);
    if (headers != null && headers.containsKey('Authorization')) {
      final authHeader = headers['Authorization']!;
      if (authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7);
        AppLogger.auth('Request with token: ${_maskToken(token)}');
      }
    } else {
      AppLogger.auth('Request without authorization token', isError: true);
    }
  }

  // Enhanced response logging with error details
  void _logResponse(String endpoint, int statusCode, {String? body, bool isError = false}) {
    AppLogger.apiResponse(endpoint, statusCode);
    if (statusCode == 401) {
      AppLogger.auth('401 Unauthorized - token invalid or expired', isError: true);
      if (body != null) AppLogger.auth('401 Response body: $body');
    } else if (statusCode == 403) {
      AppLogger.auth('403 Forbidden - insufficient permissions or invalid token', isError: true);
      if (body != null) AppLogger.auth('403 Response body: $body');
    } else if (isError && body != null) {
      AppLogger.api('Error response body: $body', isError: true);
    }
  }

  // Initialize authentication token from storage
  Future<void> initializeAuth() async {
    if (_isInitialized) {
      AppLogger.auth('Auth already initialized, skipping...');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      
      if (storedToken != null && storedToken.isNotEmpty) {
        AppLogger.auth('Found stored auth token, validating...');
        _authToken = storedToken;
        
        // Validate the stored token
        final isValid = await validateToken();
        if (!isValid) {
          AppLogger.auth('Stored token is invalid, clearing it', isError: true);
          // clearAuth() is already called in validateToken() for invalid tokens
          AppLogger.auth('App will require fresh login');
        } else {
          AppLogger.auth('Stored token is valid and ready to use');
        }
      } else {
        AppLogger.auth('No existing auth token found');
      }
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.auth('Failed to load auth token from storage: $e', isError: true);
      // Clear any potentially corrupted token data
      await clearAuth();
      _isInitialized = true;
    }
  }

  // Ensure authentication is initialized before making API calls
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeAuth();
    }
  }

  // Save authentication token to storage
  Future<void> _saveAuthToken(String token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      AppLogger.auth('Auth token saved to storage successfully');
    } catch (e) {
      AppLogger.auth('Failed to save auth token to storage', isError: true);
    }
  }

  // Clear authentication token
  Future<void> clearAuth() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      AppLogger.auth('Auth token cleared from storage');
    } catch (e) {
      AppLogger.auth('Failed to clear auth token from storage', isError: true);
    }
  }

  // Validate current token and handle auth errors
  Future<bool> validateToken() async {
    if (_authToken == null || _authToken!.isEmpty) {
      AppLogger.auth('No token available for validation', isError: true);
      return false;
    }

    try {
      AppLogger.auth('Validating current token: ${_maskToken(_authToken)}');
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/auth/me"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        AppLogger.auth('Token validation successful');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.auth('Token validation failed - ${response.statusCode} ${response.statusCode == 401 ? 'Unauthorized' : 'Forbidden'} (token may be corrupted)', isError: true);
        await clearAuth(); // Clear invalid token
        return false;
      }

      AppLogger.auth('Token validation failed with status: ${response.statusCode}', isError: true);
      return false;
    } catch (e) {
      AppLogger.auth('Token validation error: $e', isError: true);
      // If validation fails due to network/server issues, don't clear the token
      // It might be valid but server is unreachable
      if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        AppLogger.auth('Network issue during validation - keeping token for retry');
        return false;
      }
      // For other errors, clear the token as it might be corrupted
      AppLogger.auth('Clearing potentially corrupted token due to validation error');
      await clearAuth();
      return false;
    }
  }

  // Handle authentication errors consistently
  Future<void> handleAuthError(int statusCode, String endpoint) async {
    if (statusCode == 401 || statusCode == 403) {
      AppLogger.auth('Auth error on $endpoint - clearing token and forcing re-login', isError: true);
      await clearAuth();
      // In a real app, you would also trigger a navigation to login screen
      // For now, we just log the requirement
      AppLogger.auth('User must re-login to continue using the app', isError: true);
    }
  }

  // Check if user is currently authenticated (has valid token)
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  // Get current auth token (masked for logging purposes)
  String get currentTokenMasked => _maskToken(_authToken);


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
      // Log the registration attempt with masked password (safe)
      AppLogger.auth('Register attempt: $email | password: ${_maskPassword(password)}');
      
      final requestHeaders = {"Content-Type": "application/json"};
      _logRequest('POST', '/auth/register', headers: requestHeaders);
      
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/auth/register"),
        headers: requestHeaders,
        body: jsonEncode({
          "email": email,
          "password": password,
          if (name != null) "name": name,
          if (phone != null) "phone": phone,
          if (emergencyContact != null) "emergency_contact": emergencyContact,
          if (emergencyPhone != null) "emergency_phone": emergencyPhone,
        }),
      ).timeout(timeout);

      _logResponse('/auth/register', response.statusCode, body: response.body);

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
      AppLogger.auth('User registration failed', isError: true);
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
      // Log the login attempt with masked password (safe)
      AppLogger.auth('Login attempt: $email | password: ${_maskPassword(password)}');
      
      final requestHeaders = {"Content-Type": "application/json"};
      _logRequest('POST', '/auth/login', headers: requestHeaders);
      
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/auth/login"),
        headers: requestHeaders,
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      ).timeout(timeout);

      _logResponse('/auth/login', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["access_token"];
        
        // Validate token format and length
        if (token == null || token.isEmpty) {
          throw HttpException("Invalid token received from server");
        }
        
        // Log token info for security (masked)
        AppLogger.auth('Login successful - token received: ${_maskToken(token)}');
        
        await _saveAuthToken(token);
        return {
          "success": true,
          "access_token": token,
          "token_type": data["token_type"] ?? "bearer",
          "user_id": data["user_id"],
          "email": data["email"],
          "role": data["role"] ?? "tourist",
        };
      }

      final errorData = jsonDecode(response.body);
      throw HttpException("Login failed: ${errorData['detail'] ?? errorData['message'] ?? 'Invalid credentials'}");
    } catch (e) {
      AppLogger.auth('User login failed: $e', isError: true);
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
        AppLogger.auth('Token validation failed - 403 Forbidden (token may be corrupted)', isError: true);
        
        // Token validation failed with 403
        
        throw HttpException("Authentication failed. Please login again. (Token may be corrupted)");
      } else if (response.statusCode == 401) {
        throw HttpException("Authentication expired. Please login again.");
      }

      throw HttpException("Failed to get user profile: ${response.statusCode}");
    } catch (e) {
      AppLogger.auth('Failed to get current user profile', isError: true);
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
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/location/update"),
        headers: requestHeaders,
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/location/update');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to update location: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Location update failed', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow; // Let auth errors bubble up
      }
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
      AppLogger.location('Failed to load location history', isError: true);
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
      AppLogger.service('Trip start failed', isError: true);
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
      AppLogger.service('Trip end failed', isError: true);
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
      AppLogger.service('Failed to load trip history', isError: true);
      return {
        "success": false,
        "message": "Failed to load trip history.",
      };
    }
  }

  // Safety and emergency endpoints
  Future<Map<String, dynamic>> getSafetyScore() async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/safety/score', headers: requestHeaders);
      
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/safety/score"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/safety/score', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Safety score retrieved successfully');
        return {
          "success": true,
          "safety_score": data["safety_score"],
          "risk_level": data["risk_level"],
          "last_updated": data["last_updated"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/safety/score');
        return {
          "success": false,
          "message": response.statusCode == 401 
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.",
          "auth_error": true,
        };
      }

      throw HttpException("Failed to get safety score: ${response.statusCode} - ${response.body}");
    } catch (e) {
      AppLogger.error('Safety score request failed', error: e);
      return {
        "success": false,
        "message": "Failed to get safety score: ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> triggerSOS() async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('POST', '/sos/trigger', headers: requestHeaders);

      final response = await client
          .post(
            Uri.parse("$baseUrl$apiPrefix/sos/trigger"),
            headers: requestHeaders,
          )
          .timeout(timeout);

      _logResponse('/sos/trigger', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.emergency('SOS triggered successfully');
        return {
          "success": true,
          "status": data["status"] ?? "sos_triggered",
          "alert_id": data["alert_id"],
          "notifications_sent": data["notifications_sent"],
          "timestamp": data["timestamp"],
        };
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/sos/trigger');
        final msg = response.statusCode == 401
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.";
        return {
          "success": false,
          "message": msg,
          "auth_error": true,
          "status_code": response.statusCode,
        };
      }

      // Try to surface server-provided message if available
      String? serverMsg;
      try {
        final body = jsonDecode(response.body);
        serverMsg = body['detail'] ?? body['message'];
      } catch (_) {}

      throw HttpException(
          "Failed to trigger SOS: ${response.statusCode}${serverMsg != null ? ' - $serverMsg' : ''}");
    } catch (e) {
      AppLogger.emergency('SOS trigger failed: $e', isError: true);
      return {
        "success": false,
        "message": "Failed to send SOS alert. ${e is HttpException ? e.message : 'Please try again.'}",
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
      AppLogger.service('Location search failed', isError: true);
      return [];
    }
  }

  // Geofencing and zone management
  Future<Map<String, dynamic>> checkGeofence({
    required double lat,
    required double lon,
  }) async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      final response = await client.post(
        Uri.parse("$baseUrl$apiPrefix/ai/geofence/check"),
        headers: requestHeaders,
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/ai/geofence/check');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to check geofence: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Geofence check failed', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow; // Let auth errors bubble up
      }
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
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/heatmap/zones/public', headers: requestHeaders);
      
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/heatmap/zones/public"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/heatmap/zones/public', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> zones = data['zones'] ?? [];
        AppLogger.info('Safety zones retrieved successfully (${zones.length} zones)');
        return zones.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/heatmap/zones/public');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load safety zones: ${response.statusCode} - ${response.body}");
    } catch (e) {
      AppLogger.location('Failed to load safety zones', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow; // Let auth errors bubble up
      }
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
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/alerts/recent', headers: requestHeaders);
      
      // Get recent alerts to generate heatmap data
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/alerts/recent?limit=1000&severity=high"),
        headers: requestHeaders,
      ).timeout(timeout);
      
      _logResponse('/alerts/recent', response.statusCode, body: response.body);
      
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
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Tourist users don't have access to alert data - this is expected
        AppLogger.auth('Alert data access denied (role: tourist) - returning empty heatmap', isError: false);
        return []; // Return empty list gracefully
      }

      AppLogger.api('Panic alert heatmap request failed: ${response.statusCode}', isError: true);
      return [];
    } catch (e) {
      AppLogger.api('Panic alert heat data request failed', isError: true);
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
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      // Use the heatmap zones endpoint which provides better data structure
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/heatmap/zones/public', headers: requestHeaders);
      
      final response = await client.get(
        Uri.parse("$baseUrl$apiPrefix/heatmap/zones/public"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/heatmap/zones/public', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> zones = data['zones'] ?? [];
        
        final List<RestrictedZone> restrictedZones = zones
            .map<RestrictedZone>((item) => RestrictedZone.fromJson(item))
            .toList();
        
        AppLogger.info('Loaded ${restrictedZones.length} restricted zones from heatmap API');
        return restrictedZones;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/heatmap/zones/public');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load restricted zones: ${response.statusCode} - ${response.body}");
    } catch (e) {
      AppLogger.location('Failed to load restricted zones from heatmap API', isError: true);
      
      // Return empty list instead of crashing the app
      AppLogger.location('Returning empty restricted zones list for graceful degradation', isError: true);
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
