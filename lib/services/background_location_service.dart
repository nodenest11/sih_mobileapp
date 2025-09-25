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
  static const String _logTag = '[BackgroundLocation]';
  
  // Battery-optimized location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update only if moved 10+ meters
  );

  static bool _isConfigured = false;
  static StreamSubscription<Position>? _positionSubscription;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('$_logTag $message');
    }
  }

  /// Initialize the background service with optimized settings
  static Future<bool> initializeService() async {
    try {
      final service = FlutterBackgroundService();

      if (!_isConfigured) {
        // Initialize notification channel only from main isolate; guard exceptions.
        try {
          await PersistentNotificationManager.initialize();
        } catch (e) {
          _log('Warning: notification init failed in main isolate context: $e');
        }

        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: onStart,
            autoStart: true,
            autoStartOnBoot: true,
            isForegroundMode: true,
            notificationChannelId: _notificationChannelId,
            initialNotificationTitle: 'Tourist Safety App',
            initialNotificationContent: 'Location tracking is active',
            foregroundServiceNotificationId: _notificationId,
          ),
          iosConfiguration: IosConfiguration(
            autoStart: true,
            onForeground: onStart,
            onBackground: onIosBackground,
          ),
        );

        _isConfigured = true;
        _log('Service configured (autoStart: true, autoStartOnBoot: true).');
      }

      final isRunning = await service.isRunning();
      if (!isRunning) {
        try { await PersistentNotificationManager.startPersistentNotification(); } catch (_) {}
        await service.startService();
        _log('Foreground service started.');
      } else {
        try { await PersistentNotificationManager.startPersistentNotification(); } catch (_) {}
        _log('Foreground service already running; ensured persistent notification.');
      }

      return await service.isRunning();
    } catch (e) {
      _log('Failed to initialize background service: $e');
      return false;
    }
  }

  /// Main service entry point - optimized for battery efficiency
  /// Entry point for the background service
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
    // Avoid initializing plugins that are not background-safe; attempt a silent notification update.
    try {
      await PersistentNotificationManager.startPersistentNotification();
      _log('onStart invoked; persistent notification ensured.');
    } catch (e) {
      _log('Notification call in background isolate failed (safe to ignore on some devices): $e');
    }

    // Real-time stream listener for significant movement
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 20),
      ),
    ).listen(
      (position) async {
        _log('Stream position received lat=${position.latitude}, lng=${position.longitude}, acc=${position.accuracy}.');
        await _handleBackgroundPosition(position);
      },
      onError: (error) {
        _log('Background location stream error: $error');
      },
    );

    // Fallback timer to ensure periodic updates if stream pauses
    Timer? serviceTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance && !(await service.isForegroundService())) {
        await service.setAsForegroundService();
        _log('Fallback timer promoted service back to foreground.');
      }
      await _trackLocation(service);
    });

    service.on('stopService').listen((event) {
      serviceTimer.cancel();
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _log('Service stop requested; cleaned up timers and subscriptions.');
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
        _log('Location permission required (permission=$permission).');
        return;
      }

      // Get current position with battery-optimized settings
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      ).timeout(const Duration(seconds: 10));

      await _handleBackgroundPosition(position);
    } catch (e) {
      _log('Location tracking error: $e');
    }
  }

  static Future<void> _handleBackgroundPosition(Position position) async {
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

        _log('Location pushed lat=${position.latitude.toStringAsFixed(5)} lng=${position.longitude.toStringAsFixed(5)} acc=${position.accuracy}m.');
      } else {
        _log('Location skipped (no significant movement / within 1 min window).');
      }
    } else {
      _log('Tourist ID not found in SharedPreferences; skipping update.');
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
    
    // Force update every minute regardless of distance
    final timeSinceLastUpdate = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    if (timeSinceLastUpdate >= 60 * 1000) {
      return true;
    }
    
    // Calculate distance moved and only update if significant
    final distance = Geolocator.distanceBetween(
      lastLat, lastLng,
      position.latitude, position.longitude,
    );
    
    // Update if moved more than 10 meters (aligned with distance filter)
    final shouldUpdate = distance > 10.0;
    if (!shouldUpdate) {
      _log('Distance since last update ${distance.toStringAsFixed(2)}m — below threshold, skipping.');
    }
    return shouldUpdate;
  }

  /// Send location update to backend with error handling
  static Future<void> _sendLocationUpdate(String touristId, Position position) async {
    try {
      final touristIdInt = int.tryParse(touristId);
      if (touristIdInt == null) return;

      final response = await http.post(
        Uri.parse('http://159.89.166.91:8000/locations/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tourist_id': touristIdInt,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _log('Failed to update location: HTTP ${response.statusCode} ${response.body}');
      } else {
        _log('Backend acknowledge status ${response.statusCode}.');
      }
    } catch (e) {
      _log('Location update error: $e');
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