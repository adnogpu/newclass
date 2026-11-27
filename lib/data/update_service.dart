import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReleaseHistoryEntry {
  const ReleaseHistoryEntry({required this.versionName, required this.notes});

  final String versionName;
  final String notes;

  factory ReleaseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReleaseHistoryEntry(
      versionName: '${json['versionName'] ?? json['version'] ?? ''}'.trim(),
      notes: '${json['notes'] ?? ''}'.trim(),
    );
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apk,
    required this.sha256,
    required this.size,
    required this.notes,
    this.publishedAt,
    this.history = const [],
  });

  final String versionName;
  final int versionCode;
  final String apk;
  final String sha256;
  final int size;
  final String notes;
  final DateTime? publishedAt;
  final List<ReleaseHistoryEntry> history;

  double get sizeMb => size <= 0 ? 0 : size / (1024 * 1024);

  String get downloadUrl => UpdateService.proxyDownloadUrl(apk);

  String get directDownloadUrl => UpdateService.directDownloadUrl(apk);

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final apk = '${json['apk'] ?? 'newclass.apk'}';
    if (!RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(apk)) {
      throw const UpdateException('更新包文件名无效');
    }
    final sha = '${json['sha256'] ?? ''}'.toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) {
      throw const UpdateException('更新包校验值无效');
    }
    final codeValue = json['versionCode'];
    final code = codeValue is num
        ? codeValue.toInt()
        : int.tryParse('$codeValue');
    if (code == null || code <= 0) {
      throw const UpdateException('更新版本号无效');
    }
    final sizeValue = json['size'];
    final size = sizeValue is num
        ? sizeValue.toInt()
        : int.tryParse('$sizeValue') ?? 0;
    final history = <ReleaseHistoryEntry>[];
    final seenVersions = <String>{};
    final historyValue = json['history'];
    if (historyValue is List) {
      for (final item in historyValue) {
        if (item is! Map) continue;
        final entry = ReleaseHistoryEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (entry.versionName.isEmpty || entry.notes.isEmpty) continue;
        if (!seenVersions.add(entry.versionName)) continue;
        history.add(entry);
      }
    }
    return UpdateInfo(
      versionName: '${json['versionName'] ?? '新版本'}',
      versionCode: code,
      apk: apk,
      sha256: sha,
      size: size,
      notes: '${json['notes'] ?? ''}'.trim(),
      publishedAt: DateTime.tryParse('${json['publishedAt'] ?? ''}'),
      history: history,
    );
  }

  /// Combines every release newer than [currentVersionName] up to this
  /// release. The single-release case stays unchanged so the dialog does not
  /// repeat the version already shown in its title.
  UpdateInfo forUpgradeFrom(String currentVersionName) {
    final current = currentVersionName.trim();
    if (current.isEmpty) return this;

    final entries = <ReleaseHistoryEntry>[...history];
    final hasLatest = entries.any(
      (entry) =>
          UpdateService.compareVersionNames(entry.versionName, versionName) ==
          0,
    );
    if (!hasLatest && notes.isNotEmpty) {
      entries.add(ReleaseHistoryEntry(versionName: versionName, notes: notes));
    }
    final newer = entries.where((entry) {
      final afterCurrent = UpdateService.compareVersionNames(
        entry.versionName,
        current,
      );
      final atOrBeforeLatest = UpdateService.compareVersionNames(
        entry.versionName,
        versionName,
      );
      return afterCurrent > 0 && atOrBeforeLatest <= 0;
    }).toList();
    if (newer.isEmpty) return this;
    newer.sort(
      (a, b) => UpdateService.compareVersionNames(b.versionName, a.versionName),
    );
    final combined = newer.length == 1
        ? newer.single.notes
        : newer
              .map((entry) => '## ${entry.versionName}\n\n${entry.notes}')
              .join('\n\n');
    return UpdateInfo(
      versionName: versionName,
      versionCode: versionCode,
      apk: apk,
      sha256: sha256,
      size: size,
      notes: combined,
      publishedAt: publishedAt,
      history: history,
    );
  }
}

class UpdateService {
  UpdateService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  static const proxyBase = 'https://v4.gh-proxy.org/';
  static const repoBase = 'https://github.com/adnogpu/newclass';
  static const _versionPath = '/releases/download/latest/version.json';
  static const _downloadPath = '/releases/download/latest/';
  static const _channel = MethodChannel('newclass/native');

  final http.Client _client;
  final Duration timeout;

  static String proxyDownloadUrl(String apk) =>
      '$proxyBase$repoBase$_downloadPath$apk';

  static String directDownloadUrl(String apk) => '$repoBase$_downloadPath$apk';

  Future<UpdateInfo> fetchLatest() async {
    final urls = ['$proxyBase$repoBase$_versionPath', '$repoBase$_versionPath'];
    for (final url in urls) {
      try {
        final uri = Uri.parse(url).replace(
          queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'},
        );
        final response = await _client
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(timeout);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          return UpdateInfo.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Try the next endpoint.
      }
    }
    throw const UpdateException('检查更新失败');
  }

  Future<UpdateInfo?> check() async {
    final latest = await fetchLatest();
    final current = await _currentVersion();
    if (!isNewer(latest.versionCode, current.code)) return null;
    return latest.forUpgradeFrom(current.name);
  }

  Future<_InstalledVersion> _currentVersion() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const _InstalledVersion(0, '');
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'appVersion',
      );
      final codeValue = result?['code'];
      final code = codeValue is num
          ? codeValue.toInt()
          : int.tryParse('$codeValue') ?? 0;
      return _InstalledVersion(code, '${result?['name'] ?? ''}'.trim());
    } catch (_) {
      return const _InstalledVersion(0, '');
    }
  }

  static bool isNewer(int remote, int current) => remote > current;

  static int compareVersionNames(String a, String b) {
    final left = _versionParts(a);
    final right = _versionParts(b);
    if (left.isEmpty && right.isEmpty) return 0;
    if (left.isEmpty) return -1;
    if (right.isEmpty) return 1;
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final match = RegExp(r'\d+(?:\.\d+)*').firstMatch(value);
    if (match == null) return const [];
    return match
        .group(0)!
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  void close() => _client.close();
}

class _InstalledVersion {
  const _InstalledVersion(this.code, this.name);

  final int code;
  final String name;
}
