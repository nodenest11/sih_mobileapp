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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: Text(
                      widget.tourist.name.isNotEmpty 
                          ? widget.tourist.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Name
                Text(
                  widget.tourist.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Tourist ID
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ID: ${widget.tourist.id}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contact Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.tourist.phone != null) ...[
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: '+91 ${widget.tourist.phone}',
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.tourist.email != null) ...[
                  _buildInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: widget.tourist.email!,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Registered',
                  value: widget.tourist.registrationDate != null
                      ? '${widget.tourist.registrationDate!.day}/${widget.tourist.registrationDate!.month}/${widget.tourist.registrationDate!.year}'
                      : 'Today',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Location Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingLocationSettings)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _buildInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location Service',
                    value: _locationSettings['serviceEnabled'] == true ? 'Enabled' : 'Disabled',
                    valueColor: _locationSettings['serviceEnabled'] == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.security_outlined,
                    label: 'Permission',
                    value: _locationSettings['permission']?.toString().split('.').last ?? 'Unknown',
                    valueColor: _locationSettings['permission']?.toString().contains('granted') == true ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.track_changes_outlined,
                    label: 'Tracking',
                    value: _locationSettings['isTracking'] == true ? 'Active' : 'Inactive',
                    valueColor: _locationSettings['isTracking'] == true ? Colors.green : Colors.grey,
                  ),
                ],
              ],
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
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? const Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}