import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

/// PanicService is responsible for enforcing a cooldown window between panic alerts,
/// sending the panic alert to backend, and exposing remaining cooldown time.
class PanicService {
  static const String _lastPanicKey = 'last_panic_timestamp';
  static const Duration cooldown = Duration(hours: 1);

  final ApiService _apiService;
  final GeolocatorPlatform _geolocator;

  PanicService({ApiService? apiService, GeolocatorPlatform? geolocator})
      : _apiService = apiService ?? ApiService(),
        _geolocator = geolocator ?? GeolocatorPlatform.instance;

  /// Returns the DateTime of last panic alert or null.
  Future<DateTime?> getLastPanicTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastPanicKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Returns true if still cooling down.
  Future<bool> isCoolingDown() async {
    final last = await getLastPanicTime();
    if (last == null) return false;
    return DateTime.now().isBefore(last.add(cooldown));
  }

  /// Remaining cooldown duration, or Duration.zero if not cooling down.
  Future<Duration> remaining() async {
    final last = await getLastPanicTime();
    if (last == null) return Duration.zero;
    final end = last.add(cooldown);
    final diff = end.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Sends panic alert if not cooling down. Throws if disallowed or fails.
  Future<Map<String, dynamic>> sendPanicAlert({required int touristId}) async {
    if (await isCoolingDown()) {
      final rem = await remaining();
      throw PanicCooldownException(rem);
    }

    Position position;
    try {
      position = await _geolocator.getCurrentPosition();
    } catch (e) {
      // fallback attempt with reduced accuracy
      position = await _geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
    }

    final response = await _apiService.sendPanicAlert(
      touristId: touristId,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (response['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastPanicKey, DateTime.now().millisecondsSinceEpoch);
      return response;
    }
    throw Exception(response['message'] ?? 'Unknown panic alert failure');
  }
}

class PanicCooldownException implements Exception {
  final Duration remaining;
  PanicCooldownException(this.remaining);
  @override
  String toString() => 'Panic alert cooling down. Remaining: ${remaining.inMinutes}m';
}
