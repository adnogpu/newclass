import 'dart:async';

import 'widget_bridge_stub.dart'
    if (dart.library.io) 'widget_bridge_io.dart' as impl;

Future<void> publishWidgetData({
  required String key,
  required String data,
  required String provider,
  required String qualifiedProvider,
}) => impl.publishWidgetData(
  key: key,
  data: data,
  provider: provider,
  qualifiedProvider: qualifiedProvider,
);

Future<Uri?> initialWidgetLaunch() => impl.initialWidgetLaunch();

Stream<Uri?> widgetClickStream() => impl.widgetClickStream();
