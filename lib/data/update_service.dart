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

class UpdateInfo {
  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apk,
    required this.sha256,
    required this.size,
    required this.notes,
    this.publishedAt,
  });

  final String versionName;
  final int versionCode;
  final String apk;
  final String sha256;
  final int size;
  final String notes;
  final DateTime? publishedAt;

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
    return UpdateInfo(
      versionName: '${json['versionName'] ?? '新版本'}',
      versionCode: code,
      apk: apk,
      sha256: sha,
      size: size,
      notes: '${json['notes'] ?? ''}'.trim(),
      publishedAt: DateTime.tryParse('${json['publishedAt'] ?? ''}'),
    );
  }
}

class UpdateService {
  UpdateService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  static const proxyBase = 'https://gh-proxy.com/';
  static const repoBase = 'https://github.com/adnogpu/newclass';
  static const _versionPath = '/releases/download/latest/version.json';
  static const _downloadPath = '/releases/download/latest/';
  static const _channel = MethodChannel('newclass/native');

  final http.Client _client;
  final Duration timeout;

  static String proxyDownloadUrl(String apk) =>
      '$proxyBase$repoBase$_downloadPath$apk';

  static String directDownloadUrl(String apk) =>
      '$repoBase$_downloadPath$apk';

  Future<UpdateInfo> fetchLatest() async {
    final urls = [
      '$proxyBase$repoBase$_versionPath',
      '$repoBase$_versionPath',
    ];
    for (final url in urls) {
      try {
        final uri = Uri.parse(url).replace(
          queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'},
        );
        final response = await _client
            .get(
              uri,
              headers: {'Accept': 'application/json'},
            )
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
    final currentCode = await _currentVersionCode();
    return isNewer(latest.versionCode, currentCode) ? latest : null;
  }

  Future<int> _currentVersionCode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 0;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'appVersion',
      );
      final code = result?['code'];
      if (code is num) return code.toInt();
      return int.tryParse('$code') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static bool isNewer(int remote, int current) => remote > current;

  void close() => _client.close();
}
