import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Settings Manager - Centralized app settings management
/// Handles all user preferences and syncs across the app
class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  // SharedPreferences instance
  SharedPreferences? _prefs;

  // Settings Keys
  static const String keyLocationTracking = 'location_tracking';
  static const String keyPushNotifications = 'push_notifications';
  static const String keySosAlerts = 'sos_alerts';
  static const String keySafetyAlerts = 'safety_alerts';
  static const String keyProximityAlerts = 'proximity_alerts';
  static const String keyGeofenceAlerts = 'geofence_alerts';
  static const String keyBatteryOptimization = 'battery_optimization';
  static const String keyUpdateInterval = 'update_interval';
  static const String keyNotificationSound = 'notification_sound';
  static const String keyNotificationVibration = 'notification_vibration';
  static const String keyAutoStartTracking = 'auto_start_tracking';
  static const String keyDarkMode = 'dark_mode';
  static const String keyLanguage = 'language';
  static const String keyMapType = 'map_type';
  static const String keyProximityRadius = 'proximity_radius';
  static const String keyShowResolvedAlerts = 'show_resolved_alerts';
  static const String keyOfflineMode = 'offline_mode';

  // Default Values
  static const bool defaultLocationTracking = true;
  static const bool defaultPushNotifications = true;
  static const bool defaultSosAlerts = true;
  static const bool defaultSafetyAlerts = true;
  static const bool defaultProximityAlerts = true;
  static const bool defaultGeofenceAlerts = true;
  static const bool defaultBatteryOptimization = false;
  static const String defaultUpdateInterval = '10';
  static const bool defaultNotificationSound = true;
  static const bool defaultNotificationVibration = true;
  static const bool defaultAutoStartTracking = true;
  static const bool defaultDarkMode = false;
  static const String defaultLanguage = 'en';
  static const String defaultMapType = 'standard';
  static const int defaultProximityRadius = 5;
  static const bool defaultShowResolvedAlerts = false;
  static const bool defaultOfflineMode = false;

  /// Initialize settings manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    AppLogger.info('✅ Settings Manager initialized');
  }

  /// Get SharedPreferences instance
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('SettingsManager not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // ========== LOCATION & TRACKING ==========

  bool get locationTracking => 
      prefs.getBool(keyLocationTracking) ?? defaultLocationTracking;
  
  Future<void> setLocationTracking(bool value) async {
    await prefs.setBool(keyLocationTracking, value);
    AppLogger.info('📍 Location tracking: ${value ? "ON" : "OFF"}');
  }

  String get updateInterval => 
      prefs.getString(keyUpdateInterval) ?? defaultUpdateInterval;
  
  Future<void> setUpdateInterval(String value) async {
    await prefs.setString(keyUpdateInterval, value);
    AppLogger.info('⏱️ Update interval: ${value}s');
  }

  int get updateIntervalSeconds => int.tryParse(updateInterval) ?? 10;

  bool get batteryOptimization => 
      prefs.getBool(keyBatteryOptimization) ?? defaultBatteryOptimization;
  
  Future<void> setBatteryOptimization(bool value) async {
    await prefs.setBool(keyBatteryOptimization, value);
    AppLogger.info('🔋 Battery optimization: ${value ? "ON" : "OFF"}');
  }

  bool get autoStartTracking => 
      prefs.getBool(keyAutoStartTracking) ?? defaultAutoStartTracking;
  
  Future<void> setAutoStartTracking(bool value) async {
    await prefs.setBool(keyAutoStartTracking, value);
    AppLogger.info('🚀 Auto-start tracking: ${value ? "ON" : "OFF"}');
  }

  // ========== NOTIFICATIONS ==========

  bool get pushNotifications => 
      prefs.getBool(keyPushNotifications) ?? defaultPushNotifications;
  
  Future<void> setPushNotifications(bool value) async {
    await prefs.setBool(keyPushNotifications, value);
    AppLogger.info('🔔 Push notifications: ${value ? "ON" : "OFF"}');
  }

  bool get sosAlerts => 
      prefs.getBool(keySosAlerts) ?? defaultSosAlerts;
  
  Future<void> setSosAlerts(bool value) async {
    await prefs.setBool(keySosAlerts, value);
    AppLogger.info('🚨 SOS alerts: ${value ? "ON" : "OFF"}');
  }

  bool get safetyAlerts => 
      prefs.getBool(keySafetyAlerts) ?? defaultSafetyAlerts;
  
  Future<void> setSafetyAlerts(bool value) async {
    await prefs.setBool(keySafetyAlerts, value);
    AppLogger.info('⚠️ Safety alerts: ${value ? "ON" : "OFF"}');
  }

  bool get proximityAlerts => 
      prefs.getBool(keyProximityAlerts) ?? defaultProximityAlerts;
  
  Future<void> setProximityAlerts(bool value) async {
    await prefs.setBool(keyProximityAlerts, value);
    AppLogger.info('📍 Proximity alerts: ${value ? "ON" : "OFF"}');
  }

  bool get geofenceAlerts => 
      prefs.getBool(keyGeofenceAlerts) ?? defaultGeofenceAlerts;
  
  Future<void> setGeofenceAlerts(bool value) async {
    await prefs.setBool(keyGeofenceAlerts, value);
    AppLogger.info('🚧 Geofence alerts: ${value ? "ON" : "OFF"}');
  }

  bool get notificationSound => 
      prefs.getBool(keyNotificationSound) ?? defaultNotificationSound;
  
  Future<void> setNotificationSound(bool value) async {
    await prefs.setBool(keyNotificationSound, value);
    AppLogger.info('🔊 Notification sound: ${value ? "ON" : "OFF"}');
  }

  bool get notificationVibration => 
      prefs.getBool(keyNotificationVibration) ?? defaultNotificationVibration;
  
  Future<void> setNotificationVibration(bool value) async {
    await prefs.setBool(keyNotificationVibration, value);
    AppLogger.info('📳 Notification vibration: ${value ? "ON" : "OFF"}');
  }

  // ========== APPEARANCE ==========

  bool get darkMode => 
      prefs.getBool(keyDarkMode) ?? defaultDarkMode;
  
  Future<void> setDarkMode(bool value) async {
    await prefs.setBool(keyDarkMode, value);
    AppLogger.info('🌙 Dark mode: ${value ? "ON" : "OFF"}');
  }

  String get language => 
      prefs.getString(keyLanguage) ?? defaultLanguage;
  
  Future<void> setLanguage(String value) async {
    await prefs.setString(keyLanguage, value);
    AppLogger.info('🌐 Language: $value');
  }

  // ========== MAP SETTINGS ==========

  String get mapType => 
      prefs.getString(keyMapType) ?? defaultMapType;
  
  Future<void> setMapType(String value) async {
    await prefs.setString(keyMapType, value);
    AppLogger.info('🗺️ Map type: $value');
  }

  int get proximityRadius => 
      prefs.getInt(keyProximityRadius) ?? defaultProximityRadius;
  
  Future<void> setProximityRadius(int value) async {
    await prefs.setInt(keyProximityRadius, value);
    AppLogger.info('📏 Proximity radius: ${value}km');
  }

  bool get showResolvedAlerts => 
      prefs.getBool(keyShowResolvedAlerts) ?? defaultShowResolvedAlerts;
  
  Future<void> setShowResolvedAlerts(bool value) async {
    await prefs.setBool(keyShowResolvedAlerts, value);
    AppLogger.info('✅ Show resolved alerts: ${value ? "ON" : "OFF"}');
  }

  // ========== ADVANCED ==========

  bool get offlineMode => 
      prefs.getBool(keyOfflineMode) ?? defaultOfflineMode;
  
  Future<void> setOfflineMode(bool value) async {
    await prefs.setBool(keyOfflineMode, value);
    AppLogger.info('📴 Offline mode: ${value ? "ON" : "OFF"}');
  }

  // ========== UTILITY METHODS ==========

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await prefs.clear();
    AppLogger.warning('🔄 All settings reset to defaults');
  }

  /// Get all settings as a map (for debugging)
  Map<String, dynamic> getAllSettings() {
    return {
      'location_tracking': locationTracking,
      'push_notifications': pushNotifications,
      'sos_alerts': sosAlerts,
      'safety_alerts': safetyAlerts,
      'proximity_alerts': proximityAlerts,
      'geofence_alerts': geofenceAlerts,
      'battery_optimization': batteryOptimization,
      'update_interval': updateInterval,
      'notification_sound': notificationSound,
      'notification_vibration': notificationVibration,
      'auto_start_tracking': autoStartTracking,
      'dark_mode': darkMode,
      'language': language,
      'map_type': mapType,
      'proximity_radius': proximityRadius,
      'show_resolved_alerts': showResolvedAlerts,
      'offline_mode': offlineMode,
    };
  }

  /// Export settings as JSON string
  String exportSettings() {
    return getAllSettings().toString();
  }

  /// Print all settings (debug)
  void printAllSettings() {
    AppLogger.info('📋 Current Settings:');
    getAllSettings().forEach((key, value) {
      AppLogger.info('  $key: $value');
    });
  }
}
