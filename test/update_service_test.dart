import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:newclass/data/update_service.dart';

Map<String, dynamic> _payload({
  int code = 12,
  String versionName = '1.0.2',
  String notes = 'Automated build',
}) => {
  'versionName': versionName,
  'versionCode': code,
  'apk': 'newclass.apk',
  'sha256': 'a' * 64,
  'size': 84 * 1024 * 1024,
  'publishedAt': '2026-11-25T11:00:00Z',
  'notes': notes,
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
      'https://v4.gh-proxy.org/https://github.com/adnogpu/newclass/releases/download/latest/newclass.apk',
    );
    expect(
      info.directDownloadUrl,
      'https://github.com/adnogpu/newclass/releases/download/latest/newclass.apk',
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

  test('compares dotted version names', () {
    expect(UpdateService.compareVersionNames('1.1.2', '1.1.1'), greaterThan(0));
    expect(UpdateService.compareVersionNames('1.1', '1.1.0'), 0);
    expect(
      UpdateService.compareVersionNames('1.10.0', '1.9.9'),
      greaterThan(0),
    );
    expect(
      UpdateService.compareVersionNames('v1.0.2', '1.0.1'),
      greaterThan(0),
    );
  });

  test('combines every release between installed and latest versions', () {
    final info = UpdateInfo.fromJson({
      ..._payload(code: 30, versionName: '1.1.2', notes: 'latest fix'),
      'history': [
        {'versionName': '1.1.2', 'notes': 'latest fix'},
        {'versionName': '1.1.1', 'notes': 'middle fix'},
        {'versionName': '1.1.0', 'notes': 'old feature'},
        {'versionName': '1.0.13', 'notes': 'already installed'},
      ],
    });

    final upgrade = info.forUpgradeFrom('1.1.0');
    expect(upgrade.notes, contains('## 1.1.2'));
    expect(upgrade.notes, contains('latest fix'));
    expect(upgrade.notes, contains('## 1.1.1'));
    expect(upgrade.notes, contains('middle fix'));
    expect(upgrade.notes, isNot(contains('old feature')));
    expect(upgrade.notes, isNot(contains('already installed')));
    expect(upgrade.publishedAt, DateTime.utc(2026, 11, 25, 11));
  });

  test('keeps latest notes unchanged for a single-version upgrade', () {
    final info = UpdateInfo.fromJson({
      ..._payload(code: 30, versionName: '1.1.2', notes: 'latest fix'),
      'history': [
        {'versionName': '1.1.2', 'notes': 'latest fix'},
        {'versionName': '1.1.1', 'notes': 'middle fix'},
      ],
    });

    final upgrade = info.forUpgradeFrom('1.1.1');
    expect(upgrade.notes, 'latest fix');
    expect(upgrade.notes, isNot(contains('## 1.1.2')));
  });

  test('keeps latest notes when the installed version is unknown', () {
    final info = UpdateInfo.fromJson({
      ..._payload(versionName: '1.1.2'),
      'history': [
        {'versionName': '1.1.1', 'notes': 'middle fix'},
      ],
    });
    expect(info.forUpgradeFrom('').notes, 'Automated build');
  });

  test('falls back to top-level notes when history is unavailable', () {
    final info = UpdateInfo.fromJson(
      _payload(versionName: '1.1.2', notes: 'fallback notes'),
    );
    expect(info.forUpgradeFrom('1.0.13').notes, 'fallback notes');
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
