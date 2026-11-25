import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/data/cas_crypto.dart';

void main() {
  group('CasCrypto.rawRsaHex', () {
    test('matches the jsbn little-endian raw RSA implementation', () {
      expect(
        CasCrypto.rawRsaHex('test123'),
        '556386088bed8a24d6d61615f1d355cd79ea501e5ca52a4a8688fc2a587abeb0'
        '30c7042cbbceb8daaf92facf658a65256e96e44dcc6a7871fdeb4554067a1a23'
        '265e9a4c2f768e69b6be2bc170014fcd6a5796f2d02198964a60a1f6b6087f70'
        'a9dfd10bcffa36a37c982abee41a9744f54a735353a79593b7e2fd61a4317c0f',
      );
      expect(
        CasCrypto.rawRsaHex('lyasp1700000000000'),
        '26ec86dc6283c51c99566b413b132259139a15010d72353aa489f6df6429cd54'
        'a077cc3983726a631c3eaa8c1e5bd0533205c45545cee9deb85fbbcdd5db2461'
        '9b20173f370fad100ddcbe40e8b9fb4b5ec10b52610a361e642d83fb17978948'
        '5fa562ad5c6aa535b3ed5b6d44b8c7b556219d3c6d8353524941bc6065693d40',
      );
    });
  });

  group('parseHttpDate', () {
    test('parses an RFC 1123 date header', () {
      final parsed = parseHttpDate('Wed, 25 Nov 2026 10:06:12 GMT');
      expect(parsed, DateTime.utc(2026, 11, 25, 10, 6, 12));
    });

    test('returns null for invalid input', () {
      expect(parseHttpDate(null), isNull);
      expect(parseHttpDate('not a date'), isNull);
    });
  });
}
