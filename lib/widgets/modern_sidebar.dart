import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tourist.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/location_history_screen.dart';
import '../screens/emergency_contacts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/efir_form_screen.dart';
import '../screens/efir_history_screen.dart';
import '../screens/broadcast_screen.dart';

class ModernSidebar extends StatelessWidget {
  final Tourist tourist;
  final Function(Widget) onNavigate;

  const ModernSidebar({
    super.key,
    required this.tourist,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(child: _buildNavigationItems(context)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                tourist.name.isNotEmpty ? tourist.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tourist.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'ID: ${tourist.id}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildItem(context, Icons.home_rounded, 'Home', HomeScreen(tourist: tourist)),
        _buildItem(context, Icons.map_rounded, 'Map', MapScreen(tourist: tourist)),
        _buildItem(context, Icons.campaign_rounded, 'Emergency Broadcasts', const BroadcastScreen()),
        _buildItem(context, Icons.description_rounded, 'File E-FIR', EFIRFormScreen(tourist: tourist)),
        _buildItem(context, Icons.history_edu_rounded, 'E-FIR History', EFIRHistoryScreen(tourist: tourist)),
        _buildItem(context, Icons.location_history_rounded, 'Location History', const LocationHistoryScreen()),
        _buildItem(context, Icons.contacts_rounded, 'Emergency Contacts', const EmergencyContactsScreen()),
        _buildItem(context, Icons.person_rounded, 'Profile', ProfileScreen(tourist: tourist)),
        _buildItem(context, Icons.settings_rounded, 'Settings', const SettingsScreen()),
      ],
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF64748B), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F172A),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
      onTap: () {
        Navigator.of(context).pop();
        onNavigate(screen);
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showLogoutDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('SafeHorizon v1.0.0', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
