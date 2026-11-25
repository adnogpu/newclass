import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

Future<void> publishWidgetData({
  required String key,
  required String data,
  required String provider,
  required String qualifiedProvider,
}) async {
  if (!Platform.isAndroid) return;
  await HomeWidget.saveWidgetData<String>(key, data);
  await HomeWidget.updateWidget(
    androidName: provider,
    qualifiedAndroidName: qualifiedProvider,
  );
}

Future<Uri?> initialWidgetLaunch() async {
  if (!Platform.isAndroid) return null;
  return HomeWidget.initiallyLaunchedFromHomeWidget();
}

Stream<Uri?> widgetClickStream() =>
    Platform.isAndroid ? HomeWidget.widgetClicked : const Stream<Uri?>.empty();

Future<bool> requestWidgetPin({
  required String provider,
  required String qualifiedProvider,
}) async {
  if (!Platform.isAndroid) return false;
  try {
    final supported =
        await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!supported) return false;
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: qualifiedProvider,
    );
    return true;
  } catch (_) {
    return false;
  }
}
