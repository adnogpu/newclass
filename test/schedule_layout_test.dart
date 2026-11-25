import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/data/captcha_ocr.dart';
import 'package:newclass/features/schedule/schedule_screen.dart';

void main() {
  group('CaptchaOcr.solveText', () {
    test('solves arithmetic captcha text', () {
      expect(CaptchaOcr.solveText('5+2='), 7);
      expect(CaptchaOcr.solveText('2×8='), 16);
      expect(CaptchaOcr.solveText('9÷3='), 3);
      expect(CaptchaOcr.solveText('7-4='), 3);
      expect(CaptchaOcr.solveText('O+3='), 3);
      expect(CaptchaOcr.solveText('abc 5+2= xyz'), 7);
    });

    test('rejects unusable OCR text', () {
      expect(CaptchaOcr.solveText('abc'), isNull);
      expect(CaptchaOcr.solveText('8/0='), isNull);
    });
  });

  test('courses are placed in the day column they belong to', () {
    expect(
      scheduleCourseLeft(day: 1, dayWidth: 100, column: 0, columns: 1),
      2,
    );
    expect(
      scheduleCourseLeft(day: 2, dayWidth: 100, column: 0, columns: 1),
      102,
    );
    expect(
      scheduleCourseLeft(day: 3, dayWidth: 100, column: 1, columns: 2),
      252,
    );
  });
}
