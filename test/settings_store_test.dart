import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/core/models/electricity_balance.dart';
import 'package:newclass/core/models/room_ref.dart';
import 'package:newclass/core/models/schedule_data.dart';
import 'package:newclass/core/storage/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const _room = RoomRef(
  roomNo: '2620',
  sysid: 'S1',
  areaid: 'A1',
  districtid: 'D1',
  buildid: 'B2',
  floorid: 'F6',
  roomid: 'R2620',
  roomName: '2620室',
  buildName: '2号学生公寓',
  floorName: '6楼',
);

ScheduleData _schedule() => ScheduleData(
  semester: '2026-2027-1',
  timeModeId: 'MODE',
  weekdays: ScheduleData.weekdayNames,
  slots: const [
    ScheduleSlot(label: '1,2节', sections: [1, 2], timeRange: '08:00-09:40'),
  ],
  courses: const [],
  notes: const [],
  fetchedAt: DateTime(2026, 11, 25, 18, 12),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setup, caches and room changes are persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final credentials = FakeCredentialStore();
    final store = SettingsStore(prefs, credentials);
    await store.load();

    expect(store.isConfigured, isFalse);
    await store.saveSetup(
      account: ' testuser ',
      password: 'secret',
      roomNo: '2620',
    );
    expect(store.isConfigured, isTrue);
    expect(store.account, 'testuser');
    expect(credentials.account, 'testuser');
    expect(credentials.password, 'secret');
    expect(prefs.getString(SettingsStore.roomNoKey), '2620');

    await store.setResolvedRoom(_room);
    await store.setBalance(
      ElectricityBalance(
        degree: '12.5',
        fetchedAt: DateTime(2026, 11, 25, 14, 32),
        room: _room,
      ),
    );
    expect(store.resolvedRoom?.roomid, 'R2620');
    expect(store.balance?.displayDegree, '12.5');

    await store.updateRoomNo('1101');
    expect(store.roomNo, '1101');
    expect(store.resolvedRoom, isNull);
    expect(store.balance, isNull);
    expect(prefs.getString(SettingsStore.roomRefKey), isNull);
    expect(prefs.getString(SettingsStore.balanceKey), isNull);
  });

  test('schedule cache derives the term start and current week', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, FakeCredentialStore());
    await store.load();
    await store.saveSetup(
      account: 'testuser',
      password: 'secret',
      roomNo: '2620',
    );

    await store.saveSchedule(_schedule());
    expect(store.schedule?.semester, '2026-2027-1');
    expect(store.semesterStart, DateTime(2026, 9, 7));
    expect(store.currentWeek(DateTime(2026, 11, 25)), 12);

    await store.setSemesterStart(DateTime(2026, 11, 20));
    expect(store.semesterStart, DateTime(2026, 11, 16));
    expect(store.currentWeek(DateTime(2026, 11, 25)), 2);

    await store.saveSchedule(_schedule());
    expect(
      store.semesterStart,
      DateTime(2026, 11, 16),
      reason: 'same semester keeps the user override',
    );
  });

  test('changing the account clears the session and cached schedule', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final credentials = FakeCredentialStore();
    final store = SettingsStore(prefs, credentials);
    await store.load();
    await store.saveSetup(
      account: 'testuser',
      password: 'secret',
      roomNo: '2620',
    );
    await store.saveSchedule(_schedule());
    await store.saveScheduleCookies('{"cas.nustti.edu.cn":{"CASTGC":"x"}}');

    await store.updateAccount('otheruser');
    expect(store.account, 'otheruser');
    expect(store.schedule, isNull);
    expect(prefs.getString(SettingsStore.scheduleKey), isNull);
    expect(credentials.cookies, isNull);
    expect(store.roomNo, '2620');
  });

  test('changing the password clears the saved login session', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final credentials = FakeCredentialStore();
    final store = SettingsStore(prefs, credentials);
    await store.load();
    await store.saveSetup(
      account: 'testuser',
      password: 'secret',
      roomNo: '2620',
    );
    await store.saveSchedule(_schedule());
    await store.saveScheduleCookies('{"cas.nustti.edu.cn":{"CASTGC":"x"}}');

    await store.updatePassword('newsecret');
    expect(store.password, 'newsecret');
    expect(credentials.cookies, isNull);
    expect(store.schedule?.semester, '2026-2027-1');
  });

  test('reload restores credentials, room, schedule and cookies', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final credentials = FakeCredentialStore();
    final store = SettingsStore(prefs, credentials);
    await store.load();
    await store.saveSetup(
      account: 'testuser',
      password: 'secret',
      roomNo: '2620',
    );
    await store.saveSchedule(_schedule());
    await store.saveScheduleCookies('{"cas.nustti.edu.cn":{"CASTGC":"x"}}');

    final restored = SettingsStore(prefs, credentials);
    await restored.load();
    expect(restored.account, 'testuser');
    expect(restored.password, 'secret');
    expect(restored.roomNo, '2620');
    expect(restored.schedule?.semester, '2026-2027-1');
    expect(restored.isConfigured, isTrue);
    expect(await restored.readScheduleCookies(), contains('CASTGC'));
  });

  test('room number validation follows the campus rule', () {
    expect(SettingsStore.isValidRoomNo('2620'), isTrue);
    expect(SettingsStore.isValidRoomNo('101'), isTrue);
    expect(SettingsStore.isValidRoomNo('123456'), isTrue);
    expect(SettingsStore.isValidRoomNo('12'), isFalse);
    expect(SettingsStore.isValidRoomNo('1234567'), isFalse);
    expect(SettingsStore.isValidRoomNo('26a0'), isFalse);
  });
}
