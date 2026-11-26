import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupPermissions {
  const StartupPermissions._();

  static const _channel = MethodChannel('newclass/native');
  static const _requestedKey = 'startup_permissions_requested';

  /// Ask for the special permissions needed by widgets and background refresh
  /// once per install. They cannot be granted through the normal runtime
  /// permission dialog, so each opens the relevant system screen.
  static Future<void> requestOnce() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_requestedKey) == true) return;
      await prefs.setBool(_requestedKey, true);
      await _channel.invokeMethod('requestStartupPermissions');
    } catch (_) {}
  }
}
