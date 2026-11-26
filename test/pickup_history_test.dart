import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/data/pickup_api.dart';
import 'package:newclass/data/pickup_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

PickupResult _result(
  String orderSn, {
  int? saved = 0,
  String? otherCabinet,
}) {
  return PickupResult(
    orderSn: orderSn,
    cabinet: otherCabinet == null
        ? const PickupCabinet(
            name: '二号学生公寓',
            box: '18',
            scene: '南京理工大学泰州科技学院',
          )
        : null,
    pickupCode: '246810',
    saved: saved,
    otherCabinet: otherCabinet ?? '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores newest query first and deduplicates orders', () async {
    final store = PickupHistoryStore();
    await store.add(_result('1111111111111111111'), at: DateTime(2026, 11, 26, 9));
    await store.add(_result('2222222222222222222', saved: 1), at: DateTime(2026, 11, 26, 10));
    await store.add(_result('1111111111111111111', saved: 0), at: DateTime(2026, 11, 26, 11));

    final history = await store.load();
    expect(history.map((entry) => entry.orderSn), [
      '1111111111111111111',
      '2222222222222222222',
    ]);
    expect(history.first.queriedAt, DateTime(2026, 11, 26, 11));
    expect(history.first.statusLabel, '在柜中');
    expect(history.last.statusLabel, '已取走');
    expect(history.first.orderTail, '111111');
  });

  test('keeps at most ten entries', () async {
    final store = PickupHistoryStore();
    for (var index = 0; index < 12; index++) {
      await store.add(
        _result('1000000000000000$index'),
        at: DateTime(2026, 11, 26, 10, index),
      );
    }
    final history = await store.load();
    expect(history, hasLength(PickupHistoryStore.limit));
    expect(history.first.orderSn, '100000000000000011');
    expect(history.last.orderSn, '10000000000000002');
  });

  test('handles other-cabinet results and clears history', () async {
    final store = PickupHistoryStore();
    await store.add(
      _result('3333333333333333333', otherCabinet: '一号学生公寓'),
    );
    final history = await store.load();
    expect(history.single.isElsewhere, isTrue);
    expect(history.single.title, '一号学生公寓');
    expect(history.single.statusLabel, '其他柜机');

    await store.clear();
    expect(await store.load(), isEmpty);
  });
}
