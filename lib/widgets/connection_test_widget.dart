import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConnectionTestWidget extends StatefulWidget {
  const ConnectionTestWidget({Key? key}) : super(key: key);

  @override
  State<ConnectionTestWidget> createState() => _ConnectionTestWidgetState();
}

class _ConnectionTestWidgetState extends State<ConnectionTestWidget> {
  String _testResult = "Testing connection...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = "Testing connection...";
    });

    try {
      final apiService = ApiService();
      await apiService.initializeAuth();
      
      final isConnected = await apiService.testConnection();
      
      setState(() {
        _isLoading = false;
        if (isConnected) {
          _testResult = "✅ Server connection successful!\nServer: ${ApiService.baseUrl}";
        } else {
          _testResult = "❌ Cannot connect to server\nServer: ${ApiService.baseUrl}\nCheck if server is running";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _testResult = "❌ Connection test failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Server Connection Test",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Text(
                _testResult,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _testResult.startsWith('✅') ? Colors.green : Colors.red,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testConnection,
              child: const Text("Test Again"),
            ),
          ],
        ),
      ),
    );
  }
}