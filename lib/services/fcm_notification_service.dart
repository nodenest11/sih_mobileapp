import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart' show Color;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../firebase_options.dart';
import '../utils/logger.dart';
import 'api_service.dart';

/// Firebase Cloud Messaging service for push notifications
class FCMNotificationService {
  static final FCMNotificationService _instance = FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();
  
  String? _fcmToken;
  bool _isInitialized = false;
  
  // Navigation callback to handle notification taps
  Function(String broadcastId)? onNotificationTap;

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.service('FCM already initialized, skipping...');
      return;
    }

    try {
      AppLogger.service('🔔 Initializing Firebase Cloud Messaging...');

      // Request notification permissions
      AppLogger.service('Requesting notification permissions...');
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.service('⚠️ Permission request timed out', isError: true);
          throw Exception('FCM permission request timed out');
        },
      );

      AppLogger.service('FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.service('✅ Notification permissions granted');

        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token with timeout and retry logic
        AppLogger.service('Requesting FCM token from Firebase...');
        _fcmToken = await _firebaseMessaging.getToken().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            AppLogger.service('⚠️ FCM token request timed out after 30 seconds', isError: true);
            return null;
          },
        );
        
        if (_fcmToken != null) {
          AppLogger.service('✅ FCM Token obtained successfully!');
          AppLogger.service('Token length: ${_fcmToken!.length} characters');
          AppLogger.service('Token preview: ${_fcmToken!.substring(0, 20)}...');
          await _saveFCMToken(_fcmToken!);
          
          // Register device with backend
          await _registerDevice();
        } else {
          AppLogger.service('❌ Failed to get FCM token - this could be due to:', isError: true);
          AppLogger.service('  1. Emulator without Google Play Services', isError: true);
          AppLogger.service('  2. Network connectivity issues', isError: true);
          AppLogger.service('  3. Firebase project configuration issues', isError: true);
          AppLogger.service('  4. google-services.json mismatch', isError: true);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          AppLogger.service('FCM token refreshed');
          _fcmToken = newToken;
          _saveFCMToken(newToken);
          _registerDevice();
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background but not terminated)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Handle notification when app is opened from terminated state
        final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        _isInitialized = true;
        AppLogger.service('✅ FCM initialization complete');
      } else {
        AppLogger.service('❌ Notification permissions denied', isError: true);
      }
    } catch (e) {
      AppLogger.service('Failed to initialize FCM: $e', isError: true);
    }
  }

  /// Initialize local notifications for displaying notifications when app is in foreground
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    AppLogger.service('Local notifications initialized');
  }

  /// Create Android notification channels for critical alerts
  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Critical broadcasts channel
      const AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
        'broadcasts_channel', // Must match manifest
        'Emergency Broadcasts',
        description: 'Critical emergency broadcasts and safety alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      // High priority channel
      const AndroidNotificationChannel highPriorityChannel = AndroidNotificationChannel(
        'high_priority_channel',
        'High Priority Alerts',
        description: 'High priority safety alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Create channels
      await androidPlugin.createNotificationChannel(criticalChannel);
      await androidPlugin.createNotificationChannel(highPriorityChannel);
      
      AppLogger.service('✅ Notification channels created');
    }
  }

  /// Save FCM token to local storage
  Future<void> _saveFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      AppLogger.service('FCM token saved to local storage');
    } catch (e) {
      AppLogger.service('Failed to save FCM token: $e', isError: true);
    }
  }

  /// Register device with backend API
  Future<void> _registerDevice() async {
    if (_fcmToken == null) {
      AppLogger.service('Cannot register device: FCM token is null', isError: true);
      return;
    }

    try {
      AppLogger.service('Registering device with backend...');
      
      // Get device information
      final deviceInfo = await _getDeviceInfo();
      final appInfo = await _getAppInfo();
      
      AppLogger.service('Device: ${deviceInfo['name']} (${deviceInfo['type']})');
      AppLogger.service('App Version: ${appInfo['version']}');
      
      final response = await _apiService.registerDevice(
        deviceToken: _fcmToken!,
        deviceType: deviceInfo['type']!,
        deviceName: deviceInfo['name'],
        appVersion: appInfo['version'],
      );

      if (response['success'] == true) {
        AppLogger.service('✅ Device registered successfully with backend');
        // Handle device_id which may be null or not present
        final deviceId = response['device_id'];
        if (deviceId != null) {
          AppLogger.service('Device ID: $deviceId');
        } else {
          AppLogger.service('⚠️ Backend did not return device_id in response');
          AppLogger.service('Full response: $response');
        }
      } else {
        AppLogger.service('❌ Device registration failed: ${response['message']}', isError: true);
      }
    } catch (e) {
      AppLogger.service('Failed to register device with backend: $e', isError: true);
    }
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'type': 'android',
          'name': '${androidInfo.manufacturer} ${androidInfo.model}',
          'os_version': 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'type': 'ios',
          'name': '${iosInfo.name} (${iosInfo.model})',
          'os_version': 'iOS ${iosInfo.systemVersion}',
        };
      }
      
      return {
        'type': Platform.operatingSystem,
        'name': 'Unknown Device',
        'os_version': Platform.operatingSystemVersion,
      };
    } catch (e) {
      AppLogger.service('Failed to get device info: $e', isError: true);
      return {
        'type': Platform.isAndroid ? 'android' : 'ios',
        'name': 'Unknown Device',
        'os_version': 'Unknown',
      };
    }
  }

  /// Get app information
  Future<Map<String, String>> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'version': '${packageInfo.version}+${packageInfo.buildNumber}',
        'package': packageInfo.packageName,
      };
    } catch (e) {
      AppLogger.service('Failed to get app info: $e', isError: true);
      return {
        'version': '1.0.0+1',
        'package': 'com.example.mobile',
      };
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.service('📩 Foreground message received');
    AppLogger.service('Title: ${message.notification?.title}');
    AppLogger.service('Body: ${message.notification?.body}');
    AppLogger.service('Data: ${message.data}');

    // Show local notification
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Determine notification importance based on severity
    final severity = (message.data['severity'] ?? 'MEDIUM').toString().toUpperCase();
    final importance = _getImportanceFromSeverity(severity);
    final priority = _getPriorityFromSeverity(severity);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'broadcasts_channel',
      'Emergency Broadcasts',
      channelDescription: 'Emergency broadcasts and safety alerts',
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledOnMs: 1000,
      ledOffMs: 500,
      color: _getColorFromSeverity(severity),
      colorized: severity == 'CRITICAL' || severity == 'HIGH',
      fullScreenIntent: severity == 'CRITICAL',
      category: severity == 'CRITICAL' 
          ? AndroidNotificationCategory.alarm 
          : AndroidNotificationCategory.message,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        htmlFormatBigText: true,
        contentTitle: notification.title,
        htmlFormatContentTitle: true,
      ),
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: severity == 'CRITICAL' 
          ? InterruptionLevel.critical 
          : severity == 'HIGH'
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['broadcast_id'],
    );

    AppLogger.service('Local notification displayed with severity: $severity');
  }

  /// Get Android importance from severity
  Importance _getImportanceFromSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Importance.max;
      case 'HIGH':
        return Importance.high;
      case 'MEDIUM':
        return Importance.defaultImportance;
      case 'LOW':
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  /// Get Android priority from severity
  Priority _getPriorityFromSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Priority.max;
      case 'HIGH':
        return Priority.high;
      case 'MEDIUM':
        return Priority.defaultPriority;
      case 'LOW':
        return Priority.low;
      default:
        return Priority.defaultPriority;
    }
  }

  /// Get notification color from severity
  Color _getColorFromSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFD32F2F); // Red
      case 'HIGH':
        return const Color(0xFFF57C00); // Orange
      case 'MEDIUM':
        return const Color(0xFFFBC02D); // Yellow
      case 'LOW':
        return const Color(0xFF1976D2); // Blue
      default:
        return const Color(0xFF1976D2); // Blue
    }
  }

  /// Handle notification tap (from system tray)
  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.service('Notification tapped: ${message.data}');
    
    final broadcastId = message.data['broadcast_id'];

    if (broadcastId != null) {
      AppLogger.service('Navigating to broadcast: $broadcastId');
      // Call the navigation callback if set
      if (onNotificationTap != null) {
        onNotificationTap!(broadcastId);
      }
    }
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    AppLogger.service('Local notification tapped: ${response.payload}');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      AppLogger.service('Navigating to broadcast: ${response.payload}');
      // Call the navigation callback if set
      if (onNotificationTap != null) {
        onNotificationTap!(response.payload!);
      }
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if FCM is initialized
  bool get isInitialized => _isInitialized;

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      AppLogger.service('Subscribed to topic: $topic');
    } catch (e) {
      AppLogger.service('Failed to subscribe to topic $topic: $e', isError: true);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      AppLogger.service('Unsubscribed from topic: $topic');
    } catch (e) {
      AppLogger.service('Failed to unsubscribe from topic $topic: $e', isError: true);
    }
  }

  /// Verify device is registered with backend
  Future<bool> verifyRegistration() async {
    if (_fcmToken == null) {
      AppLogger.service('❌ No FCM token available', isError: true);
      return false;
    }

    try {
      // Try to register again (backend should handle duplicates)
      await _registerDevice();
      return true;
    } catch (e) {
      AppLogger.service('❌ Device registration verification failed: $e', isError: true);
      return false;
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  AppLogger.service('📩 Background message received');
  AppLogger.service('Title: ${message.notification?.title}');
  AppLogger.service('Body: ${message.notification?.body}');
  AppLogger.service('Data: ${message.data}');
}
