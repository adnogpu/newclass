import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/background/background_tasks.dart';
import 'core/startup_permissions.dart';
import 'core/storage/settings_store.dart';
import 'core/widgets/widget_bridge.dart';
import 'core/widgets/widget_data.dart';
import 'data/electricity_service.dart';
import 'data/schedule_service.dart';
import 'data/update_service.dart';
import 'features/electricity/electricity_screen.dart';
import 'features/pickup/pickup_screen.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/setup/setup_screen.dart';
import 'features/update/update_dialog.dart';
import 'theme/app_theme.dart';

class NewClassApp extends StatefulWidget {
  const NewClassApp({
    super.key,
    required this.store,
    required this.electricityService,
    required this.scheduleService,
    required this.widgets,
    this.enablePlatformServices = true,
  });

  final SettingsStore store;
  final ElectricityService electricityService;
  final ScheduleService scheduleService;
  final WidgetPublisher widgets;
  final bool enablePlatformServices;

  @override
  State<NewClassApp> createState() => _NewClassAppState();
}

class _NewClassAppState extends State<NewClassApp> {
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _widgetClickSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.enablePlatformServices) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initPlatform());
    }
  }

  Future<void> _initPlatform() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final initial = await initialWidgetLaunch();
      _applyWidgetUri(initial);
      _widgetClickSubscription = widgetClickStream().listen(
        _applyWidgetUri,
      );
    } catch (_) {}
    try {
      await initBackgroundRefresh();
    } catch (_) {}
    try {
      await widget.widgets.publishAll(
        schedule: widget.store.schedule,
        semesterStart: widget.store.semesterStart,
        balance: widget.store.balance,
      );
    } catch (_) {}
    if (widget.store.isConfigured) {
      await _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    final service = UpdateService();
    try {
      final info = await service.check();
      if (!mounted || info == null) return;
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await showUpdateDialog(context, info);
    } catch (_) {
      // Update checks are best-effort and must not disturb startup.
    } finally {
      service.close();
    }
  }

  void _applyWidgetUri(Uri? uri) {
    if (uri == null) return;
    if (uri.host == 'electricity') {
      _tabIndex.value = 1;
    } else if (uri.host == 'schedule') {
      _tabIndex.value = 0;
    } else if (uri.host == 'settings') {
      _tabIndex.value = 3;
    }
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    _tabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: widget.store),
        Provider<ElectricityService>.value(value: widget.electricityService),
        Provider<ScheduleService>.value(value: widget.scheduleService),
        Provider<WidgetPublisher>.value(value: widget.widgets),
      ],
      child: MaterialApp(
        title: 'newclass',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _RootGate(tabIndex: _tabIndex),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({required this.tabIndex});

  final ValueNotifier<int> tabIndex;

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsStore, bool>(
      selector: (_, store) => store.isConfigured,
      builder: (context, configured, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: configured
              ? MainShell(key: const ValueKey('main'), tabIndex: tabIndex)
              : const SetupScreen(key: ValueKey('setup')),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.tabIndex});

  final ValueNotifier<int> tabIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<bool> _loaded = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    final initial = widget.tabIndex.value.clamp(0, 3);
    _loaded[initial] = true;
    widget.tabIndex.addListener(_onTabChanged);
    StartupPermissions.requestOnce();
  }

  void _onTabChanged() {
    final index = widget.tabIndex.value;
    if (index >= 0 && index < _loaded.length && !_loaded[index]) {
      setState(() => _loaded[index] = true);
    }
  }

  @override
  void dispose() {
    widget.tabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: widget.tabIndex,
      builder: (context, index, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface,
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.08),
                  scheme.surface,
                ),
                scheme.surface,
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: IndexedStack(
              index: index,
              children: [
                _loaded[0] ? const ScheduleScreen() : const SizedBox.shrink(),
                _loaded[1]
                    ? const ElectricityScreen()
                    : const SizedBox.shrink(),
                _loaded[2] ? const PickupScreen() : const SizedBox.shrink(),
                _loaded[3] ? const SettingsScreen() : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: NavigationBarTheme(
                      data: NavigationBarTheme.of(context).copyWith(
                        backgroundColor: Colors.transparent,
                      ),
                      child: NavigationBar(
                        height: 66,
                        selectedIndex: index,
                        onDestinationSelected: (value) =>
                            widget.tabIndex.value = value,
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            selectedIcon: Icon(Icons.calendar_month_rounded),
                            label: '课表',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.bolt_outlined),
                            selectedIcon: Icon(Icons.bolt),
                            label: '电费',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.inventory_2_outlined),
                            selectedIcon: Icon(Icons.inventory_2_rounded),
                            label: '外卖柜',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings_rounded),
                            label: '设置',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
