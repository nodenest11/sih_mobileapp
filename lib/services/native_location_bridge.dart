import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeLocationBridge {
  static const MethodChannel _channel = MethodChannel('native_location_service');
  static bool _started = false;
  static const _logTag = '[NativeLocationBridge]';

  static void _log(String msg) {
    if (kDebugMode) debugPrint('$_logTag $msg');
  }

  static Future<bool> start() async {
    if (_started) return true;
    try {
      final res = await _channel.invokeMethod<bool>('start');
      _started = (res ?? false);
      _log('Start invoked result=$_started');
      return _started;
    } catch (e) {
      _log('Failed to start native service: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (!_started) return;
    try {
      await _channel.invokeMethod('stop');
      _started = false;
      _log('Stop invoked');
    } catch (e) {
      _log('Failed to stop native service: $e');
    }
  }
}
