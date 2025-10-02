import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PersistentNotificationManager {
  static const String _channelId = 'location_tracking_channel';
  static const String _channelName = 'Location Tracking';
  static const int _notificationId = 1;
  
  static FlutterLocalNotificationsPlugin? _notificationsPlugin;
  static bool _isInitialized = false;
  static bool _notificationShown = false;
  
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
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
    
    await _notificationsPlugin!.initialize(initSettings);
    await _createNotificationChannel();
    
    _isInitialized = true;
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Location tracking notification',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notificationsPlugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> initializeNotificationChannel() async {
    await initialize();
  }

  static Future<void> showLocationNotification(String message) async {
    if (_notificationShown) return;
    
    if (!_isInitialized) await initialize();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Location tracking is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      showWhen: false,
      onlyAlertOnce: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin!.show(
      _notificationId,
      'Tourist Safety App',
      message,
      details,
    );
    
    _notificationShown = true;
  }

  static Future<void> startPersistentNotification() async {
    await showLocationNotification('Location tracking is running in background');
  }

  static Future<void> updateLocationNotification(String locationInfo) async {
    // Silent - no updates to avoid popups
  }

  static Future<void> stopPersistentNotification() async {
    if (_notificationsPlugin != null) {
      await _notificationsPlugin!.cancel(_notificationId);
      _notificationShown = false;
    }
  }
}
