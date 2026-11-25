import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:newclass/app.dart';
import 'package:newclass/core/storage/settings_store.dart';
import 'package:newclass/core/widgets/widget_data.dart';
import 'package:newclass/data/electricity_api.dart';
import 'package:newclass/data/electricity_service.dart';
import 'package:newclass/data/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch asks for credentials and then opens the shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final credentials = FakeCredentialStore();
    final store = SettingsStore(prefs, credentials);
    await store.load();
    final widgets = WidgetPublisher(enabled: false);
    final electricityApi = ElectricityApi(
      client: MockClient((_) async => http.Response('unavailable', 500)),
      baseUrl: 'https://example.test/epay/wxpage/wanxiao',
    );
    final electricityService = ElectricityService(
      api: electricityApi,
      store: store,
      widgets: widgets,
    );
    final scheduleService = ScheduleService(store: store, widgets: widgets);

    await tester.pumpWidget(
      NewClassApp(
        store: store,
        electricityService: electricityService,
        scheduleService: scheduleService,
        widgets: widgets,
        enablePlatformServices: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始使用'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'testuser');
    await tester.enterText(fields.at(1), 'secret');
    await tester.enterText(fields.at(2), '2620');
    await tester.pump();

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('电费'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(store.isConfigured, isTrue);
  });
}
