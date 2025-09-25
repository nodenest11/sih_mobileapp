import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'persistent_notification_manager.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static const String _notificationChannelId = 'location_tracking_channel';
  static const int _notificationId = 1;
  
  // Battery-optimized location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 15, // Update only if moved 15+ meters
  );

  /// Initialize the background service with optimized settings
  static Future<void> initializeService() async {
    try {
      final service = FlutterBackgroundService();

      // Initialize notification manager first
      await PersistentNotificationManager.initialize();
      
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _notificationChannelId,
          initialNotificationTitle: 'Tourist Safety App',
          initialNotificationContent: 'Location tracking is active',
          foregroundServiceNotificationId: _notificationId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      
      // Start the persistent notification after service is configured
      await PersistentNotificationManager.startPersistentNotification();
      
      service.startService();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize background service: $e');
      }
    }
  }

  /// Main service entry point - optimized for battery efficiency
  @pragma('vm:entry-point')
  /// Entry point for the background service
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Increased interval to 45 seconds for better battery performance
    Timer? serviceTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await _trackLocation(service);
        }
      } else {
        await _trackLocation(service);
      }
    });

    service.on('stopService').listen((event) {
      serviceTimer.cancel();
      service.stopSelf();
    });
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Track location with smart filtering for battery optimization
  static Future<void> _trackLocation(ServiceInstance service) async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        // Only log error, don't update notification
        if (kDebugMode) {
          debugPrint('Location permission required');
        }
        return;
      }

      // Get current position with battery-optimized settings
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      ).timeout(const Duration(seconds: 10));

      // Get tourist ID from preferences
      final prefs = await SharedPreferences.getInstance();
      final touristId = prefs.getString('tourist_id');
      
      if (touristId != null) {
        // Smart location filtering - only send if significant change
        if (await _shouldUpdateLocation(position, prefs)) {
          await _sendLocationUpdate(touristId, position);
          
          // Store last position and update time
          await prefs.setDouble('last_lat', position.latitude);
          await prefs.setDouble('last_lng', position.longitude);
          await prefs.setInt('last_update', DateTime.now().millisecondsSinceEpoch);
          
          // Optional: Log successful location update for debugging
          if (kDebugMode) {
            debugPrint('Location updated: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('Tourist ID not found - Please login');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Location tracking error: $e');
      }
    }
  }

  /// Smart location filtering to reduce battery usage and network calls
  static Future<bool> _shouldUpdateLocation(Position position, SharedPreferences prefs) async {
    final lastLat = prefs.getDouble('last_lat');
    final lastLng = prefs.getDouble('last_lng');
    final lastUpdate = prefs.getInt('last_update');
    
    // Always update on first run
    if (lastLat == null || lastLng == null || lastUpdate == null) {
      return true;
    }
    
    // Force update every 5 minutes regardless of distance
    final timeSinceLastUpdate = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    if (timeSinceLastUpdate > 5 * 60 * 1000) {
      return true;
    }
    
    // Calculate distance moved and only update if significant
    final distance = Geolocator.distanceBetween(
      lastLat, lastLng,
      position.latitude, position.longitude,
    );
    
    // Update if moved more than 25 meters (optimized for battery)
    return distance > 25.0;
  }

  /// Send location update to backend with error handling
  static Future<void> _sendLocationUpdate(String touristId, Position position) async {
    try {
      final touristIdInt = int.tryParse(touristId);
      if (touristIdInt == null) return;

      final response = await http.post(
        Uri.parse('http://159.89.166.91:8000/location/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tourist_id': touristIdInt,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 && kDebugMode) {
        debugPrint('Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Location update error: $e');
      }
    }
  }

  /// Stop the background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    final service = FlutterBackgroundService();
    return service.isRunning();
  }
}