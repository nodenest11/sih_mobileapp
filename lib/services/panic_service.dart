import 'dart:async';

import 'api_service.dart';

/// PanicService is responsible for sending panic alerts to the backend immediately.
/// No cooldown restrictions - tourists can send SOS alerts anytime.
class PanicService {
  final ApiService _apiService;

  PanicService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Sends panic alert immediately without any restrictions.
  Future<Map<String, dynamic>> sendPanicAlert() async {
    // Initialize API authentication
    await _apiService.initializeAuth();

    // Send SOS alert immediately
    final response = await _apiService.triggerSOS();

    if (response['success'] == true) {
      return response;
    }
    throw Exception(response['message'] ?? 'Unknown panic alert failure');
  }
}
