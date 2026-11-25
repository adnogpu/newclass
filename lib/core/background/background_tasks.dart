import 'background_tasks_stub.dart'
    if (dart.library.io) 'background_tasks_io.dart' as impl;

Future<void> initBackgroundRefresh() => impl.initBackgroundRefresh();
