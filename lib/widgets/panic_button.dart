import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class PanicButton extends StatefulWidget {
  final String touristId;
  final VoidCallback? onPanicSent;

  const PanicButton({
    super.key,
    required this.touristId,
    this.onPanicSent,
  });

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  bool _isLoading = false;
  bool _isPanicActive = false;

  Future<void> _handlePanicPress() async {
    if (_isLoading) return;

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _isPanicActive = true;
    });

    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      // Send panic alert to backend with new API signature
      final touristIdInt = int.tryParse(widget.touristId);
      if (touristIdInt == null) {
        throw Exception('Invalid tourist ID');
      }

      final response = await _apiService.sendPanicAlert(
        touristId: touristIdInt,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (response['success'] == true) {
        _showSuccessDialog(response['message'] ?? 'Panic alert sent successfully!');
        widget.onPanicSent?.call();
      } else {
        throw Exception(response['message'] ?? 'Failed to send panic alert');
      }
    } catch (e) {
      _showErrorDialog('Failed to send panic alert: $e');
      setState(() {
        _isPanicActive = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Emergency Alert'),
            ],
          ),
          content: const Text(
            'Are you sure you want to send a panic alert? This will notify emergency services and send your current location.',
            style: TextStyle(fontSize: 16),
          ),
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
              child: const Text('Send Alert'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Alert Sent'),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetPanicButton();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(error),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _resetPanicButton() {
    setState(() {
      _isPanicActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _handlePanicPress,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
          border: Border.all(
            color: Colors.red.shade700,
            width: 2,
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPanicActive ? Icons.emergency : Icons.warning_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPanicActive ? 'ACTIVE' : 'SOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}