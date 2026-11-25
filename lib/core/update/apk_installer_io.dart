import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../data/update_service.dart';

const _channel = MethodChannel('newclass/native');

Future<bool> downloadAndInstallApk(
  UpdateInfo info, {
  required void Function(double? progress) onProgress,
}) async {
  if (!Platform.isAndroid) return false;

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/newclass-${info.versionCode}.apk');
  if (await file.exists()) {
    await file.delete();
  }

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(info.downloadUrl));
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const UpdateException('下载失败，请稍后重试');
    }

    final total = response.contentLength;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress(
          total != null && total > 0 ? received / total : null,
        );
      }
      hasher.close();
    } finally {
      await sink.close();
    }

    final digest = digestSink.value?.toString().toLowerCase();
    if (digest == null || digest != info.sha256.toLowerCase()) {
      await file.delete();
      throw const UpdateException('安装包校验失败，请重试');
    }

    final started = await _channel.invokeMethod<bool>(
      'installApk',
      {'path': file.path},
    );
    return started ?? false;
  } finally {
    client.close();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
