import 'package:flutter/material.dart';
import 'dart:async';
import '../models/tourist.dart';
import '../models/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/panic_service.dart';
// import 'panic_result_screen.dart'; // No longer needed directly; result navigation handled via countdown screen
import 'panic_countdown_screen.dart';
import '../widgets/safety_score_widget.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';

class HomeScreen extends StatefulWidget {
  final Tourist tourist;

  const HomeScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final PanicService _panicService = PanicService();
  
  SafetyScore? _safetyScore;
  List<Alert> _alerts = [];
  bool _isLoadingSafetyScore = false;
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
    _initializeServices();
    _loadSafetyScore();
    _loadAlerts();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _panicTimer?.cancel();
    _locationService.dispose();
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
    // Start location tracking
    await _locationService.startTracking(widget.tourist.id);
    
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
    setState(() {
      _isLoadingSafetyScore = true;
    });

    try {
      final touristIdInt = int.tryParse(widget.tourist.id);
      if (touristIdInt == null) {
        throw Exception('Invalid tourist ID format');
      }
      
      final score = await _apiService.getSafetyScore(touristIdInt);
      setState(() {
        _safetyScore = score;
        _isLoadingSafetyScore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSafetyScore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load safety score: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoadingAlerts = true;
    });

    try {
      final touristIdInt = int.tryParse(widget.tourist.id);
      final alerts = await _apiService.getAlerts(touristIdInt);
      setState(() {
        _alerts = alerts;
        _isLoadingAlerts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAlerts = false;
      });
    }
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
    final touristIdInt = int.tryParse(widget.tourist.id);
    if (touristIdInt == null) {
      _showErrorSnackBar('Invalid tourist ID');
      return;
    }
    // Navigate to countdown screen which will handle sending automatically after grace period.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PanicCountdownScreen(touristId: touristIdInt),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.tourist.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
        toolbarHeight: 64,
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _loadAlerts,
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
              ),
              if (_alerts.where((alert) => !alert.isRead).isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_alerts.where((alert) => !alert.isRead).length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadSafetyScore(),
            _loadAlerts(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildLocationCard(),
            const SizedBox(height: 18),

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
              ),

            _buildQuickActions(),

            // Emergency SOS Button
            _buildSosSection(),

            if (_alerts.isNotEmpty) _buildAlertsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final trackingActive = _locationService.isTracking;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.my_location, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
                    const SizedBox(height: 2),
                    Text(
                      _locationStatus,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              _isLoadingLocation
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      onPressed: _getCurrentLocation,
                      icon: Icon(Icons.refresh, color: Colors.blue.shade600),
                      tooltip: 'Refresh',
                    ),
            ],
          ),
          const SizedBox(height: 14),
          if (_currentLocationInfo != null)
            Text(
              _currentLocationInfo!['address'],
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800, height: 1.3),
            )
          else
            Text(
              'No address available',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: trackingActive ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                trackingActive ? 'Tracking active' : 'Tracking inactive',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: trackingActive ? Colors.green.shade700 : Colors.orange.shade700),
              ),
              const Spacer(),
              if (_currentLocationInfo != null)
                Text(
                  'Accuracy ${_currentLocationInfo!['accuracy']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickActionPill(Icons.map_outlined, 'Map', () => _onTabTapped(1)),
        _quickActionPill(Icons.search_outlined, 'Search', () => _onTabTapped(1)),
        _quickActionPill(Icons.refresh_outlined, 'Refresh', () async {
          await Future.wait([
            _loadSafetyScore(),
            _loadAlerts(),
          ]);
        }),
      ],
    );
  }

  Widget _quickActionPill(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.greyLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.blue.shade700),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (_isLoadingAlerts) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const Spacer(),
            if (_alerts.length > 3)
              TextButton(onPressed: _showAllAlertsDialog, child: Text('View all (${_alerts.length})')),
          ],
        ),
        const SizedBox(height: 8),
        ..._alerts.take(3).map((a) => _alertRow(a)).toList(),
      ],
    );
  }

  Widget _alertRow(Alert alert) {
    final color = _getAlertColor(alert.severity);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                          fontSize: 13,
                          fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(alert.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
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
          fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        alert.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(alert.timestamp),
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
      case AlertType.panic:
        return Icons.emergency;
      case AlertType.geoFence:
        return Icons.location_on;
      case AlertType.safety:
        return Icons.security;
      case AlertType.emergency:
        return Icons.warning;
      default:
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
          content: Text(alert.message),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: SosButton(
        disabled: disabled,
        onTap: _handleSOSPress,
        title: disabled ? 'COOLDOWN' : 'EMERGENCY SOS',
        subtitle: disabled ? 'Next in $remainingText' : 'Tap – 10s cancel window',
      ),
    );
  }
}