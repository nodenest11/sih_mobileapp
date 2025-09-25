import 'package:shared_preferences/shared_preferences.dart';

class PanicService {
  static const Duration cooldownDuration = Duration(hours: 1);
  static const String _lastPanicKey = 'last_panic_timestamp';

  Future<DateTime?> getLastPanicTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastPanicKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<bool> canTriggerPanic() async {
    final lastPanic = await getLastPanicTime();
    if (lastPanic == null) {
      return true;
    }
    final allowedAt = lastPanic.add(cooldownDuration);
    return DateTime.now().isAfter(allowedAt);
  }

  Future<Duration?> cooldownRemaining() async {
    final lastPanic = await getLastPanicTime();
    if (lastPanic == null) return null;
    final allowedAt = lastPanic.add(cooldownDuration);
    final now = DateTime.now();
    if (now.isAfter(allowedAt)) {
      return null;
    }
    return allowedAt.difference(now);
  }

  Future<void> recordPanicTrigger(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPanicKey, timestamp.millisecondsSinceEpoch);
  }

  Future<void> clearCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPanicKey);
  }
}
