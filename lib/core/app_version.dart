import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppVersion {
  const AppVersion._();

  static const _channel = MethodChannel('newclass/native');

  /// Human-readable installed version, read from the Android package instead of
  /// being hard-coded in the settings screen.
  static Future<String> label() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'newclass';
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'appVersion',
      );
      final name = '${result?['name'] ?? ''}'.trim();
      if (name.isEmpty) return 'newclass';
      final code = result?['code'];
      if (code is num) {
        return 'newclass $name (${code.toInt()})';
      }
      return 'newclass $name';
    } catch (_) {
      return 'newclass';
    }
  }
}
