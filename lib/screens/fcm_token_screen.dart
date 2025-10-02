import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/fcm_notification_service.dart';
import '../utils/logger.dart';

/// Screen to display and copy FCM token for testing
class FCMTokenScreen extends StatefulWidget {
  const FCMTokenScreen({super.key});

  @override
  State<FCMTokenScreen> createState() => _FCMTokenScreenState();
}

class _FCMTokenScreenState extends State<FCMTokenScreen> {
  final FCMNotificationService _fcmService = FCMNotificationService();
  String? _fcmToken;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getFCMToken();
  }

  Future<void> _getFCMToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Initialize FCM service if not already initialized
      if (!_fcmService.isInitialized) {
        await _fcmService.initialize();
      }

      // Get the token
      final token = _fcmService.fcmToken;
      
      if (token != null) {
        setState(() {
          _fcmToken = token;
          _isLoading = false;
        });
        AppLogger.service('✅ FCM Token retrieved: ${token.substring(0, 20)}...');
      } else {
        setState(() {
          _errorMessage = 'FCM token not available. Please ensure Firebase is properly configured.';
          _isLoading = false;
        });
        AppLogger.service('❌ FCM token is null', isError: true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get FCM token: $e';
        _isLoading = false;
      });
      AppLogger.service('Failed to get FCM token: $e', isError: true);
    }
  }

  void _copyToClipboard() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ FCM Token copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('FCM Token'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_fcmToken != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _getFCMToken,
              tooltip: 'Refresh Token',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Getting FCM Token...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildTokenDisplay(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _getFCMToken,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDisplay() {
    final tokenLength = _fcmToken?.length ?? 0;
    final isValidLength = tokenLength >= 152 && tokenLength <= 163;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isValidLength ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isValidLength ? Colors.green : Colors.orange,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isValidLength ? Icons.check_circle : Icons.warning,
                  size: 48,
                  color: isValidLength ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  isValidLength ? 'Valid FCM Token' : 'Token Retrieved',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isValidLength ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Token Length: $tokenLength characters',
                  style: TextStyle(
                    fontSize: 14,
                    color: isValidLength ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                if (!isValidLength) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ Expected: 152-163 characters',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Token Display Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key, color: Color(0xFF1E40AF)),
                    SizedBox(width: 8),
                    Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: SelectableText(
                    _fcmToken ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Token'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1E40AF)),
                    SizedBox(width: 8),
                    Text(
                      'How to Use This Token',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInstructionStep('1', 'Copy the token using the button above'),
                _buildInstructionStep('2', 'Register it with the server using:'),
                const Padding(
                  padding: EdgeInsets.only(left: 32),
                  child: Text(
                    'POST /api/device/register',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionStep('3', 'The server can now send you push notifications!'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Debug Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debug Info',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'FCM Initialized: ${_fcmService.isInitialized}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Token Length: $tokenLength chars',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Valid: $isValidLength',
                  style: TextStyle(
                    fontSize: 12,
                    color: isValidLength ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF1E40AF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
