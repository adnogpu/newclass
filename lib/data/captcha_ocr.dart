import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CaptchaOcr {
  const CaptchaOcr._();

  static const _channel = MethodChannel('newclass/native');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<int?> solve(Uint8List imageBytes) async {
    if (!isSupported) return null;
    try {
      final texts = await _channel.invokeListMethod<String>(
        'ocrCaptcha',
        {'bytes': imageBytes},
      );
      if (texts == null) return null;
      for (final text in texts) {
        final answer = solveText(text);
        if (answer != null) return answer;
      }
    } catch (_) {}
    return null;
  }

  @visibleForTesting
  static int? solveText(String input) {
    final text = input
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('＋', '+')
        .replaceAll('十', '+');
    final match = RegExp(r'(\d+)\s*([+\-*/])\s*(\d+)').firstMatch(text);
    if (match == null) return null;
    final a = int.tryParse(match.group(1)!);
    final b = int.tryParse(match.group(3)!);
    if (a == null || b == null) return null;
    switch (match.group(2)) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        return b == 0 ? null : a ~/ b;
    }
    return null;
  }
}
