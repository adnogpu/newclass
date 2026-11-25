import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/settings_store.dart';
import 'core/widgets/widget_data.dart';
import 'data/electricity_api.dart';
import 'data/electricity_service.dart';
import 'data/schedule_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = SettingsStore(prefs, SecureCredentialStore());
  await store.load();

  final widgets = WidgetPublisher();
  final electricityService = ElectricityService(
    api: ElectricityApi(),
    store: store,
    widgets: widgets,
  );
  final scheduleService = ScheduleService(store: store, widgets: widgets);

  runApp(
    NewClassApp(
      store: store,
      electricityService: electricityService,
      scheduleService: scheduleService,
      widgets: widgets,
    ),
  );
}
