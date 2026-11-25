import 'dart:convert';

/// Raw (unpadded) RSA as implemented by the CAS login page's jsbn code.
/// The plaintext bytes are interpreted as a little-endian integer.
class CasCrypto {
  const CasCrypto._();

  static final BigInt _modulus = BigInt.parse(
    '00b5eeb166e069920e80bebd1fea4829d3d1f3216f2aabe79b6c47a3c18dcee5'
    'fd22c2e7ac519cab59198ece036dcf289ea8201e2a0b9ded307f8fb704136eaeb6'
    '70286f5ad44e691005ba9ea5af04ada5367cd724b5a26fdb5120cc95b6431604bd'
    '219c6b7d83a6f8f24b43918ea988a76f93c333aa5a20991493d4eb1117e7b1',
    radix: 16,
  );
  static final BigInt _exponent = BigInt.from(0x010001);

  static String rawRsaHex(String text) {
    final bytes = utf8.encode(text);
    var message = BigInt.zero;
    for (var index = bytes.length - 1; index >= 0; index--) {
      message = (message << 8) | BigInt.from(bytes[index]);
    }
    return message.modPow(_exponent, _modulus).toRadixString(16);
  }
}

DateTime? parseHttpDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(raw);
  if (match == null) return null;
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
