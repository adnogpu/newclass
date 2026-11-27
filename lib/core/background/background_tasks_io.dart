import 'dart:io';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/electricity_api.dart';
import '../../data/schedule_api.dart';
import '../models/schedule_data.dart';
import '../storage/settings_store.dart';
import '../widgets/widget_data.dart';

const _backgroundTaskName = 'electricity-refresh';
const _backgroundTaskUniqueName = 'newclass.electricity.periodic';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      await _refreshWidgets();
    } catch (_) {
      // Keep the previous cache on any failure.
    }
    return true;
  });
}

Future<void> _refreshWidgets() async {
  final prefs = await SharedPreferences.getInstance();
  final widgets = WidgetPublisher();
  await _refreshScheduleIfDue(prefs);
  await widgets.publishSchedule(
    schedule: SettingsStore.readSchedule(prefs),
    semesterStart: SettingsStore.readSemesterStart(prefs),
  );

  final roomNo = SettingsStore.readRoomNo(prefs);
  if (!SettingsStore.isValidRoomNo(roomNo)) return;

  final api = ElectricityApi();
  try {
    var room = SettingsStore.readCachedRoom(prefs);
    if (room == null || room.roomNo != roomNo) {
      final resolved = await api.findRoom(roomNo);
      if (SettingsStore.readRoomNo(prefs) != roomNo) return;
      room = resolved;
      await SettingsStore.writeCachedRoom(prefs, room);
    }
    final balance = await api.queryBalance(room);
    if (SettingsStore.readRoomNo(prefs) != roomNo) return;
    await SettingsStore.writeCachedBalance(prefs, balance);
    await widgets.publishElectricity(balance);
  } finally {
    api.close();
  }
}

Future<void> _refreshScheduleIfDue(SharedPreferences prefs) async {
  final now = DateTime.now();
  final schedule = SettingsStore.readSchedule(prefs);
  final lastAttempt = DateTime.tryParse(
    prefs.getString(SettingsStore.scheduleAutoSyncAttemptKey) ?? '',
  );
  if (!SettingsStore.scheduleAutoSyncDue(
    now: now,
    fetchedAt: schedule?.fetchedAt,
    lastAttempt: lastAttempt,
  )) {
    return;
  }

  final credentials = SecureCredentialStore();
  String? rawCookies;
  try {
    rawCookies = await credentials.readScheduleCookies();
  } catch (_) {
    return;
  }
  if (rawCookies == null || rawCookies.trim().isEmpty) return;

  final api = ScheduleApi();
  try {
    api.importCookiesJson(rawCookies);
    final data = await api.fetchSchedule();
    try {
      await credentials.saveScheduleCookies(api.exportCookiesJson());
    } catch (_) {}
    await SettingsStore.writeSchedule(prefs, data);

    final startSemester =
        prefs.getString(SettingsStore.semesterStartForKey) ?? '';
    var semesterStart = SettingsStore.readSemesterStart(prefs);
    if (semesterStart == null || startSemester != data.semester) {
      semesterStart = SemesterCalendar.defaultStart(data.semester);
      await prefs.setString(
        SettingsStore.semesterStartKey,
        semesterStart.toIso8601String(),
      );
      await prefs.setString(SettingsStore.semesterStartForKey, data.semester);
    }
    await prefs.setString(
      SettingsStore.scheduleAutoSyncAttemptKey,
      now.toIso8601String(),
    );
  } catch (_) {
    // A background refresh is best-effort; keep the cached timetable.
  } finally {
    api.close();
  }
}

Future<void> initBackgroundRefresh() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _backgroundTaskUniqueName,
    _backgroundTaskName,
    frequency: const Duration(hours: 3),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
