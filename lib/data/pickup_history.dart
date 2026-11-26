import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pickup_api.dart';

class PickupHistoryEntry {
  const PickupHistoryEntry({
    required this.orderSn,
    required this.cabinetName,
    required this.box,
    required this.pickupCode,
    required this.saved,
    required this.otherCabinet,
    required this.queriedAt,
  });

  final String orderSn;
  final String cabinetName;
  final String box;
  final String pickupCode;
  final int? saved;
  final String otherCabinet;
  final DateTime queriedAt;

  bool get isElsewhere => otherCabinet.isNotEmpty;

  String get title {
    if (isElsewhere) return otherCabinet;
    return cabinetName.isEmpty ? '取餐柜' : cabinetName;
  }

  String get statusLabel {
    if (isElsewhere) return '其他柜机';
    if (saved == 1) return '已取走';
    if (saved == 0) return '在柜中';
    return '状态未知';
  }

  String get orderTail =>
      orderSn.length <= 6 ? orderSn : orderSn.substring(orderSn.length - 6);

  factory PickupHistoryEntry.fromJson(Map<String, dynamic> json) {
    final orderSn = '${json['orderSn'] ?? ''}'.trim();
    if (!RegExp(r'^\d{6,32}$').hasMatch(orderSn)) {
      throw const FormatException('invalid order number');
    }
    final savedRaw = json['saved'];
    final saved = savedRaw is num
        ? savedRaw.toInt()
        : int.tryParse('${savedRaw ?? ''}');
    return PickupHistoryEntry(
      orderSn: orderSn,
      cabinetName: '${json['cabinetName'] ?? ''}'.trim(),
      box: '${json['box'] ?? ''}'.trim(),
      pickupCode: '${json['pickupCode'] ?? ''}'.trim(),
      saved: saved,
      otherCabinet: '${json['otherCabinet'] ?? ''}'.trim(),
      queriedAt:
          DateTime.tryParse('${json['queriedAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'orderSn': orderSn,
    'cabinetName': cabinetName,
    'box': box,
    'pickupCode': pickupCode,
    'saved': saved,
    'otherCabinet': otherCabinet,
    'queriedAt': queriedAt.toIso8601String(),
  };
}

class PickupHistoryStore {
  static const key = 'pickup_history';
  static const limit = 10;

  Future<List<PickupHistoryEntry>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = <PickupHistoryEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          entries.add(
            PickupHistoryEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {
          // Skip corrupt entries instead of discarding the whole history.
        }
      }
      entries.sort((a, b) => b.queriedAt.compareTo(a.queriedAt));
      return entries.take(limit).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PickupHistoryEntry>> add(
    PickupResult result, {
    DateTime? at,
  }) async {
    final current = await load();
    final entry = PickupHistoryEntry(
      orderSn: result.orderSn,
      cabinetName: result.cabinet?.name ?? '',
      box: result.cabinet?.box ?? '',
      pickupCode: result.pickupCode,
      saved: result.saved,
      otherCabinet: result.otherCabinet,
      queriedAt: at ?? DateTime.now(),
    );
    final next = <PickupHistoryEntry>[
      entry,
      ...current.where((item) => item.orderSn != result.orderSn),
    ].take(limit).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return next;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
