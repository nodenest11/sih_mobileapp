import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/fcm_notification_service.dart';
import '../utils/logger.dart';

/// Debug widget to display and copy FCM token
/// Only show this in development/debug mode
class FCMTokenDisplay extends StatefulWidget {
  const FCMTokenDisplay({super.key});

  @override
  State<FCMTokenDisplay> createState() => _FCMTokenDisplayState();
}

class _FCMTokenDisplayState extends State<FCMTokenDisplay> {
  final FCMNotificationService _fcmService = FCMNotificationService();
  String? _fcmToken;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if FCM is initialized, if not, initialize it now
      if (!_fcmService.isInitialized) {
        AppLogger.service('FCM not initialized yet, initializing now...');
        await _fcmService.initialize();
        // Wait a moment for token to be obtained
        await Future.delayed(const Duration(seconds: 2));
      }
      
      final token = _fcmService.fcmToken;
      
      setState(() {
        _fcmToken = token;
        _isLoading = false;
      });

      if (token != null) {
        AppLogger.service('📱 FCM Token available: ${token.substring(0, 20)}... (${token.length} chars)');
      } else {
        AppLogger.service('⚠️ FCM Token not yet available', isError: true);
      }
    } catch (e) {
      AppLogger.service('❌ Failed to get FCM token: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    if (_fcmToken != null) {
      await Clipboard.setData(ClipboardData(text: _fcmToken!));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ FCM Token copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      AppLogger.service('📋 FCM Token copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Firebase Cloud Messaging',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_fcmToken == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '❌ FCM Token Not Available',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make sure Firebase is properly configured and permissions are granted.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadToken,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '✅ Token Ready',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_fcmToken!.length} chars',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Token display (scrollable)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _fcmToken!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy Token'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loadToken,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Instructions
                  const Text(
                    '📝 Next Steps:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Copy the token using the button above\n'
                    '2. Use it to test notifications from the server\n'
                    '3. The device is auto-registered on login',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple dialog to show FCM token
class FCMTokenDialog extends StatelessWidget {
  const FCMTokenDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const FCMTokenDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FCMTokenDisplay(),
            ],
          ),
        ),
      ),
    );
  }
}
