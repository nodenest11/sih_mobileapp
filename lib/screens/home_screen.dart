import 'package:flutter/material.dart';
import '../models/tourist.dart';
import '../models/location.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/panic_button.dart';
import '../widgets/safety_score_widget.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

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
  
  SafetyScore? _safetyScore;
  List<Alert> _alerts = [];
  bool _isLoadingSafetyScore = false;
  bool _isLoadingAlerts = false;
  String _locationStatus = 'Checking location...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadSafetyScore();
    _loadAlerts();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
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
  }

  Future<void> _loadSafetyScore() async {
    setState(() {
      _isLoadingSafetyScore = true;
    });

    try {
      final score = await _apiService.getSafetyScore(widget.tourist.id);
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
      final alerts = await _apiService.getAlerts(widget.tourist.id);
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

  void _onPanicSent() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency alert sent! Help is on the way.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
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
      floatingActionButton: PanicButton(
        touristId: widget.tourist.id,
        onPanicSent: _onPanicSent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${widget.tourist.name}!'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAlerts,
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_alerts.where((alert) => !alert.isRead).isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        '${_alerts.where((alert) => !alert.isRead).length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: _locationService.isTracking ? Colors.green : Colors.orange,
                child: Row(
                  children: [
                    Icon(
                      _locationService.isTracking ? Icons.location_on : Icons.location_off,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Safety Score Widget
              if (_isLoadingSafetyScore)
                const Card(
                  margin: EdgeInsets.all(16),
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

              // Quick Actions
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickActionButton(
                            icon: Icons.map,
                            label: 'View Map',
                            onTap: () => _onTabTapped(1),
                          ),
                          _buildQuickActionButton(
                            icon: Icons.location_searching,
                            label: 'Find Location',
                            onTap: () {
                              _onTabTapped(1);
                              // The map screen will handle location search
                            },
                          ),
                          _buildQuickActionButton(
                            icon: Icons.refresh,
                            label: 'Refresh',
                            onTap: () async {
                              await Future.wait([
                                _loadSafetyScore(),
                                _loadAlerts(),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Alerts
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Alerts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isLoadingAlerts)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_alerts.isEmpty)
                        const Text(
                          'No alerts at the moment. You\'re all set!',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ..._alerts.take(3).map((alert) => _buildAlertTile(alert)),
                      if (_alerts.length > 3)
                        TextButton(
                          onPressed: () {
                            // Show all alerts dialog or navigate to alerts screen
                            _showAllAlertsDialog();
                          },
                          child: Text('View all ${_alerts.length} alerts'),
                        ),
                    ],
                  ),
                ),
              ),

              // Safety Tips
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Safety Tips',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSafetyTip(
                        icon: Icons.location_on,
                        title: 'Keep Location On',
                        description: 'Always keep your location services enabled for emergency assistance.',
                      ),
                      _buildSafetyTip(
                        icon: Icons.phone,
                        title: 'Emergency Contacts',
                        description: 'Make sure your emergency contacts are updated in your profile.',
                      ),
                      _buildSafetyTip(
                        icon: Icons.warning,
                        title: 'Use Panic Button',
                        description: 'In case of emergency, press the red panic button to alert authorities.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSafetyTip({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
}