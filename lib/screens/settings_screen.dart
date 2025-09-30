import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  
  bool _locationTracking = true;
  bool _pushNotifications = true;
  bool _sosAlerts = true;
  bool _safetyAlerts = true;
  bool _batteryOptimization = false;
  String _updateInterval = '10';
  
  final List<String> _updateIntervals = ['5', '10', '15', '30'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locationTracking = prefs.getBool('location_tracking') ?? true;
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _sosAlerts = prefs.getBool('sos_alerts') ?? true;
      _safetyAlerts = prefs.getBool('safety_alerts') ?? true;
      _batteryOptimization = prefs.getBool('battery_optimization') ?? false;
      _updateInterval = prefs.getString('update_interval') ?? '10';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _apiService.clearAuth();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.redPrimary),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.redPrimary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.redPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.redPrimary,
        secondary: icon != null ? Icon(icon, color: AppColors.greyText) : null,
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData? icon,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        leading: icon != null ? Icon(icon, color: AppColors.greyText) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAboutDialog() {
    return AlertDialog(
      title: const Text('About SafeHorizon'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version: 1.0.0'),
          SizedBox(height: 8),
          Text('SafeHorizon Tourist Safety Platform'),
          SizedBox(height: 8),
          Text('Keeping tourists safe with real-time tracking, emergency alerts, and safety monitoring.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.redPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Location & Tracking', Icons.location_on),
          _buildSwitchTile(
            title: 'Location Tracking',
            subtitle: 'Allow app to track your location for safety',
            value: _locationTracking,
            icon: Icons.my_location,
            onChanged: (value) {
              setState(() => _locationTracking = value);
              _saveSetting('location_tracking', value);
            },
          ),
          _buildListTile(
            title: 'Update Interval',
            subtitle: 'Location update frequency: $_updateInterval seconds',
            icon: Icons.timer,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Update Interval'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _updateIntervals.map((interval) => 
                      RadioListTile<String>(
                        title: Text('$interval seconds'),
                        value: interval,
                        groupValue: _updateInterval,
                        onChanged: (value) {
                          setState(() => _updateInterval = value!);
                          _saveSetting('update_interval', value!);
                          Navigator.pop(context);
                        },
                      ),
                    ).toList(),
                  ),
                ),
              );
            },
          ),
          _buildSwitchTile(
            title: 'Battery Optimization',
            subtitle: 'Reduce location accuracy to save battery',
            value: _batteryOptimization,
            icon: Icons.battery_saver,
            onChanged: (value) {
              setState(() => _batteryOptimization = value);
              _saveSetting('battery_optimization', value);
            },
          ),

          _buildSectionHeader('Notifications', Icons.notifications),
          _buildSwitchTile(
            title: 'Push Notifications',
            subtitle: 'Receive app notifications',
            value: _pushNotifications,
            icon: Icons.notifications_active,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
              _saveSetting('push_notifications', value);
            },
          ),
          _buildSwitchTile(
            title: 'SOS Alerts',
            subtitle: 'Emergency SOS notifications',
            value: _sosAlerts,
            icon: Icons.emergency,
            onChanged: (value) {
              setState(() => _sosAlerts = value);
              _saveSetting('sos_alerts', value);
            },
          ),
          _buildSwitchTile(
            title: 'Safety Alerts',
            subtitle: 'Location-based safety warnings',
            value: _safetyAlerts,
            icon: Icons.security,
            onChanged: (value) {
              setState(() => _safetyAlerts = value);
              _saveSetting('safety_alerts', value);
            },
          ),

          _buildSectionHeader('Account', Icons.person),
          _buildListTile(
            title: 'Profile',
            subtitle: 'Edit your profile information',
            icon: Icons.person_outline,
            onTap: () {
              // Navigate to profile screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile editing coming soon')),
              );
            },
          ),
          _buildListTile(
            title: 'Emergency Contacts',
            subtitle: 'Manage emergency contact information',
            icon: Icons.contact_emergency,
            onTap: () {
              // Navigate to emergency contacts screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency contacts screen coming soon')),
              );
            },
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Sign out of your account'),
              leading: const Icon(Icons.logout, color: Colors.red),
              onTap: _logout,
            ),
          ),

          _buildSectionHeader('Support & Info', Icons.help),
          _buildListTile(
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            icon: Icons.help_outline,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Help & Support'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📧 Email: support@safehorizon.com'),
                      SizedBox(height: 8),
                      Text('📞 Emergency: 112'),
                      SizedBox(height: 8),
                      Text('🌐 Website: www.safehorizon.com'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            icon: Icons.privacy_tip,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy will open in browser')),
              );
            },
          ),
          _buildListTile(
            title: 'About',
            subtitle: 'App version and information',
            icon: Icons.info_outline,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => _buildAboutDialog(),
              );
            },
          ),

          // Debug section (only in debug mode)
          if (ApiService.debugMode) ...[
            _buildSectionHeader('Debug & Testing', Icons.bug_report),

          ],

          const SizedBox(height: 24),
          
          // App info footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'SafeHorizon Tourist Safety Platform',
                  style: TextStyle(
                    color: AppColors.greyText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: AppColors.greyText,
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
}