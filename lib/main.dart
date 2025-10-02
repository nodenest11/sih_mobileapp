import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/fcm_notification_service.dart';
import 'utils/logger.dart';
import 'theme/app_theme.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.service('📩 Background message received: ${message.messageId}');
  
  // Show notification even when app is in background or terminated
  final FlutterLocalNotificationsPlugin localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  final notification = message.notification;
  if (notification != null) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'broadcasts_channel',
      'Emergency Broadcasts',
      channelDescription: 'Emergency broadcasts and safety alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['broadcast_id']?.toString(),
    );
    
    AppLogger.service('✅ Background notification displayed');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize logging and verify configuration
  AppLogger.info('🚀 SafeHorizon Tourist App starting up...');
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.service('✅ Firebase initialized successfully');
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize FCM early (before login) so token can be obtained immediately
    try {
      final fcmService = FCMNotificationService();
      await fcmService.initialize();
      AppLogger.service('✅ FCM initialized at app startup');
    } catch (fcmError) {
      AppLogger.service('⚠️ FCM early initialization failed, will retry after login', isError: true);
    }
  } catch (e) {
    AppLogger.service('❌ Firebase initialization failed: $e', isError: true);
  }
  
  await _initializeApp();
  
  runApp(const TouristSafetyApp());
}

Future<void> _initializeApp() async {
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Store API base URL in shared preferences for background service access
  final prefs = await SharedPreferences.getInstance();
  final apiBaseUrl = dotenv.env['API_BASE_URL']!;
  await prefs.setString('api_base_url', apiBaseUrl);
  
  // Initialize API service and find working server
  final apiService = ApiService();
  await apiService.initializeAuth();
  
  // Don't initialize background service on app start to avoid crashes
  // It will be initialized when user logs in and starts tracking
}

class TouristSafetyApp extends StatelessWidget {
  const TouristSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHorizon',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // Use the new comprehensive theme
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    if (mounted) {
      if (onboardingCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
