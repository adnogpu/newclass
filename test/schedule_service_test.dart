import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/core/models/schedule_data.dart';
import 'package:newclass/core/storage/settings_store.dart';
import 'package:newclass/core/widgets/widget_data.dart';
import 'package:newclass/data/schedule_api.dart';
import 'package:newclass/data/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

ScheduleData _schedule(DateTime fetchedAt) => ScheduleData(
  semester: '2026-2027-1',
  timeModeId: 'MODE',
  weekdays: ScheduleData.weekdayNames,
  slots: const [
    ScheduleSlot(label: '1,2节', sections: [1, 2], timeRange: '08:00-09:40'),
  ],
  courses: const [],
  notes: const [],
  fetchedAt: fetchedAt,
);

class _FakeScheduleApi extends ScheduleApi {
  _FakeScheduleApi(this.data);

  final ScheduleData data;
  int fetchCount = 0;

  @override
  bool get hasCookies => true;

  @override
  void importCookiesJson(String raw) {}

  @override
  String exportCookiesJson() => '{"fake":true}';

  @override
  Future<ScheduleData> fetchSchedule() async {
    fetchCount++;
    return data;
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'daily silent sync refreshes once and then throttles for 24 hours',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs, FakeCredentialStore());
      await store.load();
      await store.saveSetup(
        account: 'testuser',
        password: 'secret',
        roomNo: '2620',
      );

      final now = DateTime(2026, 11, 27, 12);
      final api = _FakeScheduleApi(_schedule(now));
      final service = ScheduleService(
        store: store,
        widgets: WidgetPublisher(enabled: false),
        apiFactory: () => api,
      );

      expect(await service.maybeDailySilentSync(now: now), isTrue);
      expect(api.fetchCount, 1);
      expect(store.schedule?.fetchedAt, now);
      expect(store.scheduleAutoSyncAttempt, now);

      expect(await service.maybeDailySilentSync(now: now), isFalse);
      expect(api.fetchCount, 1);
    },
  );

  test('daily silent sync leaves a fresh cached timetable untouched', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs, FakeCredentialStore());
    await store.load();
    await store.saveSetup(
      account: 'testuser',
      password: 'secret',
      roomNo: '2620',
    );
    final now = DateTime(2026, 11, 27, 12);
    await store.saveSchedule(_schedule(now.subtract(const Duration(hours: 2))));

    final api = _FakeScheduleApi(_schedule(now));
    final service = ScheduleService(
      store: store,
      widgets: WidgetPublisher(enabled: false),
      apiFactory: () => api,
    );

    expect(await service.maybeDailySilentSync(now: now), isFalse);
    expect(api.fetchCount, 0);
  });
}
