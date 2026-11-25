import 'dart:async';

Future<void> publishWidgetData({
  required String key,
  required String data,
  required String provider,
  required String qualifiedProvider,
}) async {}

Future<Uri?> initialWidgetLaunch() async => null;

Stream<Uri?> widgetClickStream() => const Stream<Uri?>.empty();

Future<bool> requestWidgetPin({
  required String provider,
  required String qualifiedProvider,
}) async => false;
