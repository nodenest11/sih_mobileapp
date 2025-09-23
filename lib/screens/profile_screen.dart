import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tourist.dart';
import '../services/location_service.dart';
import '../screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Tourist tourist;

  const ProfileScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocationService _locationService = LocationService();
  Map<String, dynamic> _locationSettings = {};
  bool _isLoadingLocationSettings = true;

  @override
  void initState() {
    super.initState();
    _loadLocationSettings();
  }

  Future<void> _loadLocationSettings() async {
    try {
      final settings = await _locationService.getLocationSettings();
      setState(() {
        _locationSettings = settings;
        _isLoadingLocationSettings = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocationSettings = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showLogoutConfirmation();
    if (!confirmed) return;

    try {
      // Stop location tracking
      await _locationService.stopTracking();
      
      // Clear user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showLogoutConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout? This will stop location tracking.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Tourist Safety App',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.security,
        size: 64,
        color: Colors.blue,
      ),
      children: [
        const Text(
          'A comprehensive safety application for tourists featuring live tracking, emergency alerts, safety scoring, and restricted area notifications.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Features:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('• Live location tracking'),
        const Text('• Emergency panic button'),
        const Text('• Safety score monitoring'),
        const Text('• Geo-fencing alerts'),
        const Text('• Interactive safety map'),
        const Text('• Location search'),
      ],
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permissions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This app requires location permissions to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Track your location for safety'),
              const Text('• Send emergency alerts with your location'),
              const Text('• Provide geo-fencing notifications'),
              const Text('• Show your position on the map'),
              const SizedBox(height: 16),
              Text(
                'Current Status: ${_getPermissionStatusText()}',
                style: TextStyle(
                  color: _getPermissionStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (!_isLocationEnabled())
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _locationService.checkAndRequestPermissions();
                  _loadLocationSettings();
                },
                child: const Text('Request Permission'),
              ),
          ],
        );
      },
    );
  }

  String _getPermissionStatusText() {
    if (_locationSettings['serviceEnabled'] == false) {
      return 'Location services disabled';
    }
    
    final permission = _locationSettings['permission'];
    switch (permission) {
      case 'whileInUse':
      case 'always':
        return 'Permission granted';
      case 'denied':
        return 'Permission denied';
      case 'deniedForever':
        return 'Permission permanently denied';
      default:
        return 'Unknown status';
    }
  }

  Color _getPermissionStatusColor() {
    if (_locationSettings['serviceEnabled'] == false) {
      return Colors.red;
    }
    
    final permission = _locationSettings['permission'];
    switch (permission) {
      case 'whileInUse':
      case 'always':
        return Colors.green;
      case 'denied':
      case 'deniedForever':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  bool _isLocationEnabled() {
    final permission = _locationSettings['permission'];
    return permission == 'whileInUse' || permission == 'always';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showAboutDialog,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      widget.tourist.name.isNotEmpty 
                          ? widget.tourist.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    widget.tourist.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Tourist ID
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${widget.tourist.id}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contact Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (widget.tourist.email != null) ...[
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blue),
                      title: const Text('Email'),
                      subtitle: Text(widget.tourist.email!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  
                  if (widget.tourist.phone != null) ...[
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.blue),
                      title: const Text('Phone'),
                      subtitle: Text(widget.tourist.phone!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  
                  if (widget.tourist.email == null && widget.tourist.phone == null)
                    const Text(
                      'No contact information provided',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Location & Tracking
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location & Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_isLoadingLocationSettings)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ListTile(
                      leading: Icon(
                        _isLocationEnabled() ? Icons.location_on : Icons.location_off,
                        color: _isLocationEnabled() ? Colors.green : Colors.red,
                      ),
                      title: const Text('Location Permission'),
                      subtitle: Text(_getPermissionStatusText()),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: _showLocationPermissionDialog,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    ListTile(
                      leading: Icon(
                        _locationSettings['isTracking'] == true 
                            ? Icons.track_changes 
                            : Icons.stop_circle,
                        color: _locationSettings['isTracking'] == true 
                            ? Colors.green 
                            : Colors.grey,
                      ),
                      title: const Text('Live Tracking'),
                      subtitle: Text(
                        _locationSettings['isTracking'] == true 
                            ? 'Active - Your location is being tracked'
                            : 'Inactive - Location tracking is stopped',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    if (_locationSettings['lastUpdate'] != null)
                      ListTile(
                        leading: const Icon(Icons.schedule, color: Colors.blue),
                        title: const Text('Last Location Update'),
                        subtitle: Text(
                          _formatDateTime(_locationSettings['lastUpdate']),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // App Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Colors.blue),
                    title: const Text('Refresh Location Settings'),
                    subtitle: const Text('Update location and permission status'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _loadLocationSettings,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.info, color: Colors.blue),
                    title: const Text('About App'),
                    subtitle: const Text('Version and app information'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showAboutDialog,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}