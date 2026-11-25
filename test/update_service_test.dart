import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:newclass/data/update_service.dart';

Map<String, dynamic> _payload({int code = 12}) => {
  'versionName': '1.0.2',
  'versionCode': code,
  'apk': 'newclass.apk',
  'sha256': 'a' * 64,
  'size': 84 * 1024 * 1024,
  'publishedAt': '2026-11-25T11:00:00Z',
  'notes': 'Automated build',
};

void main() {
  test('parses update metadata and builds proxy URLs', () {
    final info = UpdateInfo.fromJson(_payload());
    expect(info.versionName, '1.0.2');
    expect(info.versionCode, 12);
    expect(info.apk, 'newclass.apk');
    expect(info.sizeMb, closeTo(84, 0.01));
    expect(
      info.downloadUrl,
      'https://gh-proxy.com/https://github.com/adnogpu/newclass/releases/latest/download/newclass.apk',
    );
    expect(
      info.directDownloadUrl,
      'https://github.com/adnogpu/newclass/releases/latest/download/newclass.apk',
    );
  });

  test('rejects unsafe or incomplete metadata', () {
    expect(
      () => UpdateInfo.fromJson({..._payload(), 'apk': '../evil.apk'}),
      throwsA(isA<UpdateException>()),
    );
    expect(
      () => UpdateInfo.fromJson({..._payload(), 'sha256': 'abc'}),
      throwsA(isA<UpdateException>()),
    );
    expect(
      () => UpdateInfo.fromJson({..._payload(), 'versionCode': 0}),
      throwsA(isA<UpdateException>()),
    );
  });

  test('compares version codes', () {
    expect(UpdateService.isNewer(12, 3), isTrue);
    expect(UpdateService.isNewer(3, 3), isFalse);
    expect(UpdateService.isNewer(2, 3), isFalse);
  });

  test('fetches version.json through gh-proxy first', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), startsWith(UpdateService.proxyBase));
      return http.Response(
        jsonEncode(_payload()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = UpdateService(client: client);
    final info = await service.fetchLatest();
    expect(info.versionCode, 12);
    service.close();
  });

  test('falls back to the direct URL when the proxy fails', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (request.url.toString().startsWith(UpdateService.proxyBase)) {
        return http.Response('proxy down', 502);
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode(_payload(code: 13))),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = UpdateService(client: client);
    final info = await service.fetchLatest();
    expect(calls, 2);
    expect(info.versionCode, 13);
    service.close();
  });
}
