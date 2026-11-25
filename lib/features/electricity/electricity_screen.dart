import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/room_ref.dart';
import '../../core/storage/settings_store.dart';
import '../../data/electricity_api.dart';
import '../../data/electricity_service.dart';

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen>
    with WidgetsBindingObserver {
  late final SettingsStore _store;
  late final ElectricityService _service;
  bool _loading = false;
  bool _refreshPending = false;
  String? _error;
  late String _lastRoomNo;

  @override
  void initState() {
    super.initState();
    _store = context.read<SettingsStore>();
    _service = context.read<ElectricityService>();
    _lastRoomNo = _store.roomNo;
    _store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  void _onStoreChanged() {
    if (!mounted) return;
    if (_store.roomNo != _lastRoomNo) {
      _lastRoomNo = _store.roomNo;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) {
      _refreshPending = true;
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.refresh();
    } on AmbiguousRoomException catch (error) {
      await _chooseBuilding(error);
    } on ElectricityNetworkException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ElectricityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '查询失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
      if (_refreshPending && mounted) {
        _refreshPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refresh();
        });
      }
    }
  }

  Future<void> _chooseBuilding(AmbiguousRoomException error) async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<RoomRef>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '选择楼栋',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                for (final room in error.candidates)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(room.buildName),
                    subtitle: Text(
                      [room.floorName, room.roomName]
                          .where((part) => part.isNotEmpty)
                          .join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(room),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    try {
      await _service.selectRoom(selected);
    } on ElectricityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balance = _store.balance;
    final roomLabel =
        balance?.room?.displayName ??
        _store.resolvedRoom?.displayName ??
        (_store.roomNo.isEmpty ? '' : '房间 ${_store.roomNo}');
    final updatedLabel = balance == null
        ? ''
        : '更新于 ${DateFormat('HH:mm').format(balance.fetchedAt)}';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Row(
              children: [
                Text('电费', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton.filledTonal(
                    tooltip: '刷新',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.meeting_room_outlined,
                          size: 20,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          roomLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balance?.displayDegree ?? '—',
                        style: TextStyle(
                          fontSize: 62,
                          height: 0.95,
                          letterSpacing: -2.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 7),
                        child: Text(
                          '度',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    updatedLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
