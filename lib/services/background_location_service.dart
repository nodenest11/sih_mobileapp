import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'persistent_notification_manager.dart';

class BackgroundLocationService {
  static const String _notificationChannelId = 'location_tracking_channel';
  static const int _notificationId = 1;

  /// Initialize the background service
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// Initialize persistent notification manager
    await PersistentNotificationManager.initialize();
    await PersistentNotificationManager.startPersistentNotification();

    /// Configure the background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
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
    
    service.startService();
  }

  /// Main service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    Timer? serviceTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
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

  /// Track location and send to backend
  static Future<void> _trackLocation(ServiceInstance service) async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        await PersistentNotificationManager.updateLocationNotification(
          'Location permission required - Please enable location access in settings',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get tourist ID from preferences
      final prefs = await SharedPreferences.getInstance();
      final touristId = prefs.getString('tourist_id');
      
      if (touristId != null) {
        // Send location to backend
        await _sendLocationUpdate(touristId, position);
        
        // Update persistent notification with current status
        await PersistentNotificationManager.updateLocationNotification(
          'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)} • ${DateTime.now().toLocal().toString().substring(11, 16)}',
        );
      } else {
        await PersistentNotificationManager.updateLocationNotification(
          'Tourist ID not found - Please login to the app',
        );
      }
    } catch (e) {
      await PersistentNotificationManager.updateLocationNotification(
        'Location tracking error: ${e.toString()}',
      );
    }
  }

  /// Send location update to backend
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      print('Location update error: $e');
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