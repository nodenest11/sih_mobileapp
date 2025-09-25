import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class PersistentNotificationManager {
  static const String _channelId = 'persistent_location_tracking';
  static const String _channelName = 'Location Tracking (Always Active)';
  static const int _notificationId = 99999; // High ID to avoid conflicts
  
  static FlutterLocalNotificationsPlugin? _notificationsPlugin;
  static bool _isInitialized = false;
  static bool _isActive = false;
  
  /// Initialize the persistent notification manager
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Request notification permissions first
    await _requestPermissions();
    
    const AndroidInitializationSettings androidInit = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosInit = 
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    
    await _notificationsPlugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create the persistent notification channel
    await _createPersistentChannel();
    
    _isInitialized = true;
  }

  /// Request all necessary permissions
  static Future<void> _requestPermissions() async {
    // Request notification permission
    await Permission.notification.request();
    
    // Request system alert window permission (for overlay)
    await Permission.systemAlertWindow.request();
    
    // Request ignore battery optimization
    await Permission.ignoreBatteryOptimizations.request();
  }

  /// Create a special notification channel that cannot be disabled
  static Future<void> _createPersistentChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Critical location tracking notification - Cannot be turned off for safety',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFFFF0000),
    );

    await _notificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Start showing the persistent notification
  static Future<void> startPersistentNotification() async {
    if (!_isInitialized) await initialize();
    if (_isActive) return;
    
    _isActive = true;
    await _showPersistentNotification(
      'Location Tracking Active',
      'Your location is being tracked for safety. This notification cannot be dismissed.',
    );
    
    // Keep refreshing the notification to prevent dismissal
    _keepNotificationAlive();
  }

  /// Update the notification with current location info
  static Future<void> updateLocationNotification(String locationInfo) async {
    if (!_isActive) return;
    
    await _showPersistentNotification(
      '🔒 Location Tracking Active',
      'Current: $locationInfo\nThis notification protects your safety and cannot be dismissed.',
    );
  }

  /// Show the actual notification
  static Future<void> _showPersistentNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Critical location tracking notification',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF0000),
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: false,
      channelShowBadge: true,
      onlyAlertOnce: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      ticker: 'Location tracking cannot be stopped',
      // Additional properties to make it sticky
      fullScreenIntent: false,
      actions: [], // No actions to prevent interaction
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin!.show(
      _notificationId,
      title,
      body,
      details,
      payload: 'persistent_tracking',
    );
  }

  /// Keep the notification alive by refreshing it periodically
  static void _keepNotificationAlive() {
    if (!_isActive) return;
    
    // Refresh notification every 10 seconds to prevent dismissal
    Future.delayed(const Duration(seconds: 10), () {
      if (_isActive) {
        _showPersistentNotification(
          '🔒 Location Tracking Active',
          'Continuously monitoring your location for safety.\nLast update: ${DateTime.now().toLocal().toString().substring(11, 16)}',
        );
        _keepNotificationAlive(); // Recursive call
      }
    });
  }

  /// Handle notification taps (show message that it cannot be dismissed)
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == 'persistent_tracking') {
      // Show system toast that notification cannot be dismissed
      SystemChannels.platform.invokeMethod('SystemSound.play', 'SystemSoundType.alert');
      // Could also show an overlay or dialog explaining why it can't be dismissed
    }
  }

  /// Stop the persistent notification (should only be called when tracking is disabled)
  static Future<void> stopPersistentNotification() async {
    _isActive = false;
    if (_notificationsPlugin != null) {
      await _notificationsPlugin!.cancel(_notificationId);
    }
  }

  /// Check if the persistent notification is currently active
  static bool get isActive => _isActive;
}