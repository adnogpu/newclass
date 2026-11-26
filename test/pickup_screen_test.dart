import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:newclass/features/pickup/pickup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows saved pickup history for quick lookup', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pickup_order_sn': '1234567890123456789',
      'pickup_history': jsonEncode([
        {
          'orderSn': '1234567890123456789',
          'cabinetName': '二号学生公寓',
          'box': '18',
          'pickupCode': '246810',
          'saved': 0,
          'otherCabinet': '',
          'queriedAt': '2026-11-26T12:30:00.000',
        },
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PickupScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('外卖柜查询'), findsOneWidget);
    expect(find.text('历史订单'), findsOneWidget);
    expect(find.text('二号学生公寓'), findsOneWidget);
    expect(find.text('在柜中'), findsOneWidget);
    expect(find.textContaining('尾号 456789'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
  });
}
