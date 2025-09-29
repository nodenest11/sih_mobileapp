import 'package:flutter/material.dart';
import 'dart:async';
import '../models/tourist.dart';
import '../models/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/panic_service.dart';
import '../services/geofencing_service.dart';
import 'panic_countdown_screen.dart';
import 'notification_screen.dart';
import '../widgets/safety_score_widget.dart';
import 'map_screen.dart';

class ModernHomeScreen extends StatefulWidget {
  final Tourist tourist;

  const ModernHomeScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final PanicService _panicService = PanicService();
  final GeofencingService _geofencingService = GeofencingService.instance;
  
  SafetyScore? _safetyScore;
  List<Alert> _alerts = [];
  bool _isLoadingSafetyScore = false;
  bool _isLoadingAlerts = false;
  bool _isLoadingLocation = false;
  String _locationStatus = 'Your location will be shared';
  Timer? _locationUpdateTimer;
  
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    _pulseAnimationController.repeat(reverse: true);

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    );
    _fadeAnimationController.forward();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _pulseAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _initializeGeofencing();
    await _loadSafetyScore();
    await _loadAlerts();
    await _startLocationTracking();
  }

  Future<void> _initializeGeofencing() async {
    // Initialize geofencing service
    await _geofencingService.initialize();
  }

  void _onGeofenceEvent() {
    // Handle geofence events if needed
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const GeofenceAlert(),
      );
    }
  }

  Future<void> _loadSafetyScore() async {
    setState(() {
      _isLoadingSafetyScore = true;
    });

    try {
      final response = await _apiService.getSafetyScore();
      if (response['success'] == true && mounted) {
        setState(() {
          _safetyScore = SafetyScore.fromJson(response['data']);
        });
      }
    } catch (e) {
      debugPrint('Error loading safety score: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSafetyScore = false;
        });
      }
    }
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoadingAlerts = true;
    });

    try {
      _alerts = await _apiService.getAlerts();
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
        });
      }
    }
  }

  Future<void> _startLocationTracking() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Starting location tracking...';
    });

    try {
      // Initialize location service by getting current position
      await _locationService.getCurrentLocation();
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 10),
        (timer) => _updateLocation(),
      );
      
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location tracking active';
        });
      }
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location tracking failed to start';
        });
      }
    }
  }

  Future<void> _updateLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        await _apiService.updateLocation(
          lat: position.latitude,
          lon: position.longitude,
        );
        if (mounted) {
          setState(() {
            _locationStatus = 'Location updated at ${DateTime.now().toString().substring(11, 19)}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  void _triggerPanic() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PanicCountdownScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              const Color(0xFFf093fb),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 80, right: 24, top: 24, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 32),
                  _buildSafetyScoreCard(),
                  const SizedBox(height: 24),
                  _buildQuickActionsGrid(),
                  const SizedBox(height: 24),
                  _buildLocationStatusCard(),
                  const SizedBox(height: 24),
                  _buildRecentAlertsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildModernPanicButton(),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.tourist.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay safe and enjoy your journey',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety Score',
                      style: TextStyle(
                        color: const Color(0xFF2D3748),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Current safety level',
                      style: TextStyle(
                        color: const Color(0xFF718096),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingSafetyScore)
            const Center(child: CircularProgressIndicator())
          else if (_safetyScore != null)
            SafetyScoreWidget(safetyScore: _safetyScore!)
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Safety score unavailable',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildActionCard(
              'View Map',
              Icons.map_rounded,
              const Color(0xFF48bb78),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapScreen(tourist: widget.tourist),
                ),
              ),
            ),
            _buildActionCard(
              'Notifications',
              Icons.notifications_rounded,
              const Color(0xFF4299e1),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isLoadingLocation 
                  ? Colors.orange 
                  : _locationStatus.contains('active') 
                      ? Colors.green 
                      : Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Status',
                  style: TextStyle(
                    color: const Color(0xFF2D3748),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _locationStatus,
                  style: TextStyle(
                    color: const Color(0xFF718096),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Alerts',
            style: TextStyle(
              color: const Color(0xFF2D3748),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingAlerts)
            const Center(child: CircularProgressIndicator())
          else if (_alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'No recent alerts',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _alerts.take(3).map((alert) => _buildAlertItem(alert)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Alert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getAlertColor(alert.type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getAlertIcon(alert.type),
            color: _getAlertColor(alert.type),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    color: const Color(0xFF2D3748),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  alert.message,
                  style: TextStyle(
                    color: const Color(0xFF718096),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getAlertColor(AlertType type) {
    switch (type) {
      case AlertType.emergency:
        return Colors.red;
      case AlertType.safety:
        return Colors.orange;
      case AlertType.general:
        return Colors.blue;
      case AlertType.panic:
        return Colors.red;
      case AlertType.geoFence:
        return Colors.orange;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.emergency:
        return Icons.error;
      case AlertType.safety:
        return Icons.warning;
      case AlertType.general:
        return Icons.info;
      case AlertType.panic:
        return Icons.emergency;
      case AlertType.geoFence:
        return Icons.location_on;
    }
  }

  Widget _buildModernPanicButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFff6b6b),
                  Color(0xFFff5252),
                ],
              ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFff5252).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFFff5252).withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(36),
                onTap: _triggerPanic,
                child: const Center(
                  child: Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Import for GeofenceAlert widget
class GeofenceAlert extends StatelessWidget {
  const GeofenceAlert({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text('Restricted Area Alert'),
        ],
      ),
      content: const Text(
        'You have entered a restricted or high-risk area. Please exercise caution and consider leaving this area.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Understood'),
        ),
      ],
    );
  }
}