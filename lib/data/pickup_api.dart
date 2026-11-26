import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PickupException implements Exception {
  const PickupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PickupNetworkException extends PickupException {
  const PickupNetworkException(super.message);
}

class PickupCabinet {
  const PickupCabinet({
    required this.name,
    required this.box,
    required this.scene,
  });

  final String name;
  final String box;
  final String scene;
}

class PickupResult {
  const PickupResult({
    required this.orderSn,
    required this.cabinet,
    required this.pickupCode,
    required this.saved,
    required this.otherCabinet,
  });

  final String orderSn;
  final PickupCabinet? cabinet;
  final String pickupCode;
  final int? saved;
  final String otherCabinet;

  bool get inCabinet => saved == 0;

  bool get pickedUp => saved == 1;

  bool get isElsewhere => otherCabinet.isNotEmpty;
}

/// Read-only client for the AIKS pickup cabinet lookup used on campus.
class PickupApi {
  PickupApi({
    http.Client? client,
    this.baseUrl = 'https://api.aiks.aiksbox.com',
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/158.0.0.0 Safari/537.36';
  static const _referer = 'https://ele.cabinet.aiks.aiksbox.com/';

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  Future<PickupResult> query(String orderSn) async {
    final order = orderSn.trim();
    if (!RegExp(r'^\d{6,32}$').hasMatch(order)) {
      throw const PickupException('请输入正确的订单号');
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v3/ele/save/info'),
            headers: {
              'Content-Type': 'application/json',
              'Origin': 'https://ele.cabinet.aiks.aiksbox.com',
              'Referer': _referer,
              'User-Agent': _userAgent,
            },
            body: jsonEncode({'sn': order}),
          )
          .timeout(timeout);
      if (response.statusCode >= 400) {
        throw const PickupNetworkException('查询服务暂不可用，请稍后重试');
      }
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map) {
        throw const PickupException('查询结果异常，请稍后重试');
      }
      if ('${decoded['code']}' != '200') {
        final message = '${decoded['msg'] ?? ''}'.trim();
        throw PickupException(
          message.isEmpty ? '查询失败，请检查订单号' : message,
        );
      }
      final data = decoded['data'];
      if (data is! Map) {
        throw const PickupException('没有查询到取餐信息');
      }
      final cabinetRaw = data['cabinet'];
      final cabinet = cabinetRaw is Map
          ? PickupCabinet(
              name: '${cabinetRaw['name'] ?? ''}'.trim(),
              box: '${cabinetRaw['box'] ?? ''}'.trim(),
              scene: '${cabinetRaw['scene'] ?? ''}'.trim(),
            )
          : null;
      final otherRaw = data['save_other'];
      final otherName = otherRaw is Map
          ? '${otherRaw['cabinet_name'] ?? otherRaw['cabinetName'] ?? ''}'.trim()
          : '';
      final savedRaw = data['saved'];
      final saved = savedRaw is num
          ? savedRaw.toInt()
          : int.tryParse('${savedRaw ?? ''}');
      return PickupResult(
        orderSn: order,
        cabinet: cabinet,
        pickupCode: '${data['code_pick'] ?? ''}'.trim(),
        saved: saved,
        otherCabinet: otherName,
      );
    } on PickupException {
      rethrow;
    } on TimeoutException {
      throw const PickupNetworkException('连接超时，请稍后重试');
    } catch (_) {
      throw const PickupNetworkException('网络连接失败，请稍后重试');
    }
  }

  void close() => _client.close();
}
