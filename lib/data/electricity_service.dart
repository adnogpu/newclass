import '../core/models/electricity_balance.dart';
import '../core/models/room_ref.dart';
import '../core/storage/settings_store.dart';
import '../core/widgets/widget_data.dart';
import 'electricity_api.dart';

class ElectricityService {
  ElectricityService({
    required this.api,
    required this.store,
    required this.widgets,
  });

  final ElectricityApi api;
  final SettingsStore store;
  final WidgetPublisher widgets;

  Future<ElectricityBalance> refresh() async {
    final cached = _validCachedRoom();
    if (cached == null) {
      final room = await _resolveRoom();
      return _queryAndStore(room);
    }
    try {
      return await _queryAndStore(cached);
    } on ElectricityApiException {
      // Cached ids can go stale after a room change on the server; retry once.
      final room = await _resolveRoom();
      return _queryAndStore(room);
    }
  }

  Future<ElectricityBalance> selectRoom(RoomRef room) async {
    if (store.roomNo != room.roomNo) {
      throw const ElectricityException('房间号已更改');
    }
    await store.setResolvedRoom(room);
    return _queryAndStore(room);
  }

  RoomRef? _validCachedRoom() {
    final room = store.resolvedRoom;
    if (room == null) return null;
    return room.roomNo == store.roomNo ? room : null;
  }

  Future<RoomRef> _resolveRoom() async {
    if (!store.hasValidRoom) {
      throw const ElectricityApiException('请先设置房间号');
    }
    final room = await api.findRoom(store.roomNo);
    if (store.roomNo != room.roomNo) {
      throw const ElectricityException('房间号已更改');
    }
    await store.setResolvedRoom(room);
    return room;
  }

  Future<ElectricityBalance> _queryAndStore(RoomRef room) async {
    final balance = await api.queryBalance(room);
    if (store.roomNo != room.roomNo) {
      throw const ElectricityException('房间号已更改');
    }
    await store.setBalance(balance);
    await widgets.publishElectricity(balance);
    return balance;
  }
}
