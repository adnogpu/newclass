import 'dart:io';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/electricity_api.dart';
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
