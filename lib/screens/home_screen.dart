import 'package:flutter/material.dart';
import 'dart:async';
import '../models/tourist.dart';
import '../models/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/panic_service.dart';
import '../services/geofencing_service.dart';
import '../services/safety_score_manager.dart';
import '../utils/logger.dart';
// import 'panic_result_screen.dart'; // No longer needed directly; result navigation handled via countdown screen
import 'panic_countdown_screen.dart';
import 'notification_screen.dart';
import '../widgets/safety_score_widget.dart';
import '../widgets/geofence_alert.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'location_history_screen.dart';
import 'emergency_contacts_screen.dart';
import 'efir_form_screen.dart';

class HomeScreen extends StatefulWidget {
  final Tourist tourist;
  final VoidCallback? onMenuTap;

  const HomeScreen({
    super.key,
    required this.tourist,
    this.onMenuTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final PanicService _panicService = PanicService();
  final GeofencingService _geofencingService = GeofencingService.instance;
  
  SafetyScore? _safetyScore;
  List<Alert> _alerts = [];
  bool _isLoadingSafetyScore = false;
  bool _safetyScoreOfflineMode = false;
  int _safetyScoreRetryCount = 0;
  static const int _maxRetryAttempts = 3;
  Timer? _safetyScoreRefreshTimer;
  bool _isLoadingAlerts = false;
  bool _isLoadingLocation = false;
  String _locationStatus = 'Your location will be sharing';
  Map<String, dynamic>? _currentLocationInfo;
  bool _panicCooldownActive = false;
  Duration _panicRemaining = Duration.zero;
  Timer? _panicTimer;

  @override
  void initState() {
    super.initState();
    AppLogger.service('🏠 HomeScreen initializing for tourist: ${widget.tourist.id}');
    AppLogger.service('🔧 DEBUG_MODE enabled: ${const bool.fromEnvironment('dart.vm.product') == false}');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // First, initialize services and auth
    await _initializeServices();
    
    // Then load data that requires authentication
    _loadSafetyScore();
    _loadAlerts();
    _getCurrentLocation();
    _initializeGeofencing();
  }

  @override
  void dispose() {
    _panicTimer?.cancel();
    _safetyScoreRefreshTimer?.cancel();
    _locationService.dispose();
    _geofencingService.stopMonitoring();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    final locationInfo = await _locationService.getCurrentLocationWithAddress();
    
    setState(() {
      _currentLocationInfo = locationInfo;
      _isLoadingLocation = false;
      if (locationInfo != null) {
        _locationStatus = 'Location sharing active';
      } else {
        _locationStatus = 'Your location will be sharing';
      }
    });
  }

  Future<void> _initializeServices() async {
    // Initialize API service and load auth token first
    AppLogger.service('🔧 Initializing API service and loading auth token...');
    await _apiService.initializeAuth();
    
    // Start location tracking
    await _locationService.startTracking();
    
    // Listen to location status updates
    _locationService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _locationStatus = status;
        });
      }
    });
    _initPanicCooldownWatcher();
  }

  Future<void> _initPanicCooldownWatcher() async {
    // Initialize cooldown state
    final cooling = await _panicService.isCoolingDown();
    if (cooling) {
      final remaining = await _panicService.remaining();
      if (mounted) {
        setState(() {
          _panicCooldownActive = true;
          _panicRemaining = remaining;
        });
      }
      _startPanicTicker();
    }
  }

  Future<void> _initializeGeofencing() async {
    // Start geofencing monitoring
    await _geofencingService.startMonitoring();
    
    // Listen to geofence events and show alerts
    _geofencingService.events.listen((event) {
      if (mounted) {
        _showGeofenceAlert(event.zone, event.eventType);
      }
    });
  }
  
  void _showGeofenceAlert(RestrictedZone zone, GeofenceEventType eventType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GeofenceAlertDialog(
        zone: zone,
        eventType: eventType,
      ),
    );
  }

  void _startPanicTicker() {
    _panicTimer?.cancel();
    _panicTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining = await _panicService.remaining();
      if (!mounted) return;
      if (remaining == Duration.zero) {
        setState(() {
          _panicCooldownActive = false;
          _panicRemaining = Duration.zero;
        });
        _panicTimer?.cancel();
      } else {
        setState(() {
          _panicCooldownActive = true;
          _panicRemaining = remaining;
        });
      }
    });
  }

  Future<void> _loadSafetyScore() async {
    AppLogger.api('🎯 Enhanced safety score loading for tourist: ${widget.tourist.id}');
    
    if (_isLoadingSafetyScore) {
      AppLogger.api('⏳ Safety score loading already in progress, skipping...');
      return;
    }

    setState(() {
      _isLoadingSafetyScore = true;
      _safetyScoreOfflineMode = false;
    });

    try {
      // First, try to get cached data for immediate display
      Map<String, dynamic>? cachedScore = await SafetyScoreManager.getCachedSafetyScore();
      if (cachedScore != null && _safetyScore == null) {
        AppLogger.api('⚡ Displaying cached safety score while loading fresh data');
        _updateSafetyScoreUI(cachedScore, isFromCache: true);
      }

      // Attempt to load fresh data with retry logic
      Map<String, dynamic>? freshScore = await _loadSafetyScoreWithRetry();
      
      if (freshScore != null) {
        // Success - use fresh data
        AppLogger.api('✅ Fresh safety score loaded successfully');
        await SafetyScoreManager.cacheSafetyScore(freshScore);
        _updateSafetyScoreUI(freshScore);
        _safetyScoreRetryCount = 0; // Reset retry count on success
        _schedulePeriodicRefresh();
      } else {
        // Failed - try intelligent offline calculation
        AppLogger.warning('⚠️ API failed, attempting offline calculation...');
        Map<String, dynamic>? offlineScore = await _calculateOfflineSafetyScore();
        
        if (offlineScore != null) {
          AppLogger.api('🔋 Using offline safety score calculation');
          _updateSafetyScoreUI(offlineScore, isOffline: true);
        } else if (cachedScore != null) {
          AppLogger.api('💾 Falling back to cached data');
          _updateSafetyScoreUI(cachedScore, isFromCache: true);
        } else {
          // Last resort - show default safe score with warning
          _showFallbackSafetyScore();
        }
      }
    } catch (e) {
      AppLogger.error('🚨 Critical error in safety score loading: $e');
      _handleSafetyScoreError(e);
    } finally {
      setState(() {
        _isLoadingSafetyScore = false;
      });
    }
  }

  /// Load safety score with intelligent retry logic
  Future<Map<String, dynamic>?> _loadSafetyScoreWithRetry() async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        AppLogger.api('📡 Attempt $attempt/$_maxRetryAttempts: Calling getSafetyScore API...');
        
        final response = await _apiService.getSafetyScore().timeout(
          Duration(seconds: 10 + (attempt * 5)), // Progressive timeout
        );
        
        AppLogger.api('📋 Received response: $response');
        
        if (response['success'] == true) {
          AppLogger.api('✅ API call successful on attempt $attempt');
          return {
            "success": true,
            "safety_score": response['safety_score'],
            "risk_level": response['risk_level'],
            "last_updated": response['last_updated'],
            "source": "api",
          };
        } else if (response['auth_error'] == true) {
          AppLogger.error('🚫 Authentication error - stopping retry attempts');
          return null; // Don't retry auth errors
        } else {
          AppLogger.warning('⚠️ API returned success=false on attempt $attempt: $response');
        }
      } catch (e) {
        AppLogger.warning('🔄 Attempt $attempt failed: $e');
        
        if (attempt < _maxRetryAttempts) {
          int delaySeconds = attempt * 2; // Progressive delay: 2s, 4s, 6s
          AppLogger.api('⏱️ Waiting ${delaySeconds}s before retry...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }
    
    AppLogger.error('❌ All retry attempts failed for safety score');
    _safetyScoreRetryCount++;
    return null;
  }

  /// Calculate safety score offline using intelligent algorithms
  Future<Map<String, dynamic>?> _calculateOfflineSafetyScore() async {
    try {
      // Get current location
      LocationData? currentLocation;
      if (_currentLocationInfo != null) {
        currentLocation = LocationData(
          touristId: widget.tourist.id,
          latitude: _currentLocationInfo!['lat'] ?? 0.0,
          longitude: _currentLocationInfo!['lng'] ?? 0.0,
          timestamp: DateTime.now(),
        );
      }

      // Get cached risk zones and incidents
      List<Map<String, dynamic>> riskZones = []; // TODO: Implement zone caching
      List<Map<String, dynamic>> recentIncidents = []; // TODO: Implement incident caching
      
      // Get cached score for smoothing
      int? previousScore = _safetyScore?.score;
      
      // Calculate using intelligent algorithm
      return await SafetyScoreManager.calculateIntelligentSafetyScore(
        currentLocation: currentLocation,
        riskZones: riskZones,
        recentIncidents: recentIncidents,
        timeOfDay: DateTime.now().hour.toString(),
        cachedScore: previousScore,
      );
    } catch (e) {
      AppLogger.error('🚨 Offline calculation failed: $e');
      return null;
    }
  }

  /// Update the UI with safety score data
  void _updateSafetyScoreUI(Map<String, dynamic> scoreData, {bool isFromCache = false, bool isOffline = false}) {
    final score = SafetyScore(
      touristId: widget.tourist.id,
      score: scoreData['safety_score'] ?? 75,
      riskLevel: scoreData['risk_level'] ?? 'medium',
      scoreBreakdown: Map<String, double>.from(
        scoreData['score_breakdown']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      componentWeights: Map<String, double>.from(
        scoreData['component_weights']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      recommendations: List<String>.from(scoreData['recommendations'] ?? []),
      lastUpdated: DateTime.tryParse(scoreData['last_updated'] ?? '') ?? DateTime.now(),
    );
    
    setState(() {
      _safetyScore = score;
      _safetyScoreOfflineMode = isOffline;
    });
    
    // Log the update with appropriate emoji
    String source = isFromCache ? '💾 cache' : isOffline ? '🔋 offline' : '🌐 API';
    AppLogger.api('🎉 Safety score updated from $source: ${score.score}% (${score.level})');
    
    // Show user-friendly notification for offline mode
    if (isOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Text('Using offline safety calculation'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Handle safety score loading errors gracefully
  void _handleSafetyScoreError(dynamic error) {
    AppLogger.error('📍 Error details: ${error.runtimeType} - ${error.toString()}');
    
    String userMessage = 'Unable to load safety score';
    Color backgroundColor = Colors.red;
    
    // Provide specific user-friendly messages based on error type
    if (error.toString().contains('TimeoutException')) {
      userMessage = 'Connection timeout - using cached data';
      backgroundColor = Colors.orange;
    } else if (error.toString().contains('SocketException')) {
      userMessage = 'No internet connection - using offline mode';
      backgroundColor = Colors.blue;
    } else if (_safetyScoreRetryCount > 5) {
      userMessage = 'Service temporarily unavailable';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(userMessage)),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _loadSafetyScore(),
          ),
        ),
      );
    }
  }

  /// Show a fallback safety score when all else fails
  void _showFallbackSafetyScore() {
    final fallbackScore = SafetyScore(
      touristId: widget.tourist.id,
      score: 75, // Default to medium-safe
      riskLevel: 'medium',
      scoreBreakdown: {},
      componentWeights: {},
      recommendations: ['Please check your connection for updated safety information.'],
      lastUpdated: DateTime.now(),
    );
    
    setState(() {
      _safetyScore = fallbackScore;
      _safetyScoreOfflineMode = true;
    });
    
    AppLogger.warning('🔒 Using fallback safety score: 75% (medium)');
  }

  /// Schedule periodic refresh of safety score
  void _schedulePeriodicRefresh() {
    _safetyScoreRefreshTimer?.cancel();
    _safetyScoreRefreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isLoadingSafetyScore) {
        AppLogger.api('🔄 Periodic safety score refresh');
        _loadSafetyScore();
      }
    });
  }

  Future<void> _loadAlerts() async {
    // Individual alerts are handled through push notifications
    // Alert history can be accessed through dedicated screens
    setState(() {
      _isLoadingAlerts = false;
      _alerts = [];
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // _onPanicSent removed; feedback handled inside countdown/result screens.

  Future<void> _handleSOSPress() async {
    if (_panicCooldownActive) {
      _showErrorSnackBar('SOS already sent. Try again in ${_panicRemaining.inMinutes}m');
      return;
    }
    
    // Navigate to countdown screen which will handle sending automatically after grace period.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PanicCountdownScreen(),
      ),
    ).then((_) async {
      // After returning (either cancelled or sent) refresh cooldown + alerts state
      final cooling = await _panicService.isCoolingDown();
      if (!mounted) return;
      if (cooling) {
        final remaining = await _panicService.remaining();
        setState(() {
          _panicCooldownActive = true;
          _panicRemaining = remaining;
        });
        _startPanicTicker();
        _loadAlerts();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _navigateToNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationScreen(
          touristId: widget.tourist.id,
          initialAlerts: _alerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(),
      MapScreen(tourist: widget.tourist),
      ProfileScreen(tourist: widget.tourist),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppBar(
              leading: widget.onMenuTap != null
                  ? IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: widget.onMenuTap,
                      tooltip: 'Menu',
                    )
                  : null,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SafeHorizon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Hi, ${widget.tourist.name.split(' ')[0]}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              actions: [
                Stack(
                  children: [
                    IconButton(
                      onPressed: _navigateToNotifications,
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                    ),
                    if (_alerts.where((alert) => !alert.isAcknowledged).isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadSafetyScore(),
                  _loadAlerts(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
            // Safety Score Widget
            if (_isLoadingSafetyScore)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_safetyScore != null)
              SafetyScoreWidget(
                safetyScore: _safetyScore!,
                onRefresh: _loadSafetyScore,
                isOfflineMode: _safetyScoreOfflineMode,
                isFromCache: false,
              ),

            const SizedBox(height: 16),

            _buildLocationCard(),
            
            const SizedBox(height: 16),

            // Emergency SOS Button
            _buildSosSection(),

            if (_alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildAlertsSection(),
            ],

            const SizedBox(height: 16),

            _buildQuickActions(),

            const SizedBox(height: 20),
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF1E40AF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _locationStatus,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingLocation)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Refresh location',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: const Color(0xFF64748B),
                ),
            ],
          ),
          if (_currentLocationInfo != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentLocationInfo!['address'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleActionButton(
                icon: Icons.map_rounded,
                label: 'Map',
                onTap: () => _onTabTapped(1),
              ),
              _buildSimpleActionButton(
                icon: Icons.description_rounded,
                label: 'E-FIR',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EFIRFormScreen(tourist: widget.tourist)),
                  );
                },
              ),
              _buildSimpleActionButton(
                icon: Icons.location_history_rounded,
                label: 'History',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LocationHistoryScreen()),
                  );
                },
              ),
              _buildSimpleActionButton(
                icon: Icons.person_rounded,
                label: 'Profile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen(tourist: widget.tourist)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleActionButton(
                icon: Icons.contacts_rounded,
                label: 'Contacts',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()),
                  );
                },
              ),
              _buildSimpleActionButton(
                icon: Icons.description_rounded,
                label: 'E-FIR',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EFIRFormScreen(tourist: widget.tourist)),
                  );
                },
              ),
              const SizedBox(width: 60), // Spacer
              const SizedBox(width: 60), // Spacer
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                icon,
                size: 24,
                color: const Color(0xFF1E40AF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (_isLoadingAlerts)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              if (_alerts.length > 3)
                TextButton(
                  onPressed: _showAllAlertsDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View all (${_alerts.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._alerts.take(3).map((alert) => _buildAlertItem(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Alert alert) {
    final color = _getAlertColor(alert.severity);
    final isUnread = !alert.isAcknowledged;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnread ? color.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnread ? color.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getAlertIcon(alert.type),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatTime(alert.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Removed legacy _buildQuickActionButton after redesign.

  Widget _buildAlertTile(Alert alert) {
    return ListTile(
      leading: Icon(
        _getAlertIcon(alert.type),
        color: _getAlertColor(alert.severity),
      ),
      title: Text(
        alert.title,
        style: TextStyle(
          fontWeight: alert.isAcknowledged ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        alert.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(alert.createdAt),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () {
        // Mark as read and show alert details
        _showAlertDialog(alert);
      },
    );
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.sos:
        return Icons.emergency;
      case AlertType.geofence:
        return Icons.location_on;
      case AlertType.safety:
        return Icons.security;
      case AlertType.emergency:
        return Icons.warning;
      case AlertType.anomaly:
        return Icons.warning_amber;
      case AlertType.sequence:
        return Icons.timeline;
      case AlertType.general:
        return Icons.info;
    }
  }

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.high:
        return Colors.orange;
      case AlertSeverity.medium:
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _showAlertDialog(Alert alert) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getAlertIcon(alert.type),
                color: _getAlertColor(alert.severity),
              ),
              const SizedBox(width: 8),
              Text(alert.title),
            ],
          ),
          content: Text(alert.description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAllAlertsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'All Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      return _buildAlertTile(_alerts[index]);
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSosSection() {
    final disabled = _panicCooldownActive;
    final remainingText = _panicRemaining.inMinutes > 0
        ? '${_panicRemaining.inMinutes}m'
        : _panicRemaining.inSeconds > 0
            ? '${_panicRemaining.inSeconds}s'
            : 'Ready';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: disabled
              ? [const Color(0xFF64748B), const Color(0xFF475569)]
              : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (disabled ? const Color(0xFF64748B) : const Color(0xFFDC2626))
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : _handleSOSPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    disabled ? Icons.schedule_rounded : Icons.emergency_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        disabled ? 'SOS COOLDOWN' : 'EMERGENCY SOS',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disabled
                            ? 'Available in $remainingText'
                            : 'Tap to trigger emergency alert',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
