import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/data/captcha_ocr.dart';

void main() {
  test('parses arithmetic from ddddocr output', () {
    expect(CaptchaOcr.solveText('3+5='), 8);
    expect(CaptchaOcr.solveText('8*7='), 56);
    expect(CaptchaOcr.solveText('9÷3='), 3);
    expect(CaptchaOcr.solveText('9-4='), 5);
    expect(CaptchaOcr.solveText('8*1三'), 8);
    expect(CaptchaOcr.solveText('3十5三'), 8);
  });

  test('rejects text without a complete arithmetic expression', () {
    expect(CaptchaOcr.solveText('请输入验证码'), isNull);
    expect(CaptchaOcr.solveText('9+'), isNull);
  });
}
