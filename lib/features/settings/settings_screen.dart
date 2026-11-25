import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/schedule_data.dart';
import '../../core/storage/settings_store.dart';
import '../../core/widgets/widget_data.dart';
import '../../data/update_service.dart';
import '../update/update_dialog.dart';

const _nativeChannel = MethodChannel('newclass/native');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final scheme = Theme.of(context).colorScheme;
    final start = store.semesterStart;
    final schedule = store.schedule;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Text('设置', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          Material(
            color: scheme.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  label: '教务账号',
                  value: store.account,
                  onTap: () => _editAccount(context, store),
                ),
                const Divider(indent: 66, endIndent: 18),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  label: '密码',
                  value: store.password.isEmpty ? '未设置' : '••••••••',
                  onTap: () => _editPassword(context, store),
                ),
                const Divider(indent: 66, endIndent: 18),
                _SettingsRow(
                  icon: Icons.meeting_room_outlined,
                  label: '宿舍房间号',
                  value: store.roomNo,
                  onTap: () => _editRoom(context, store),
                ),
                const Divider(indent: 66, endIndent: 18),
                _SettingsRow(
                  icon: Icons.event_available_outlined,
                  label: '开学日期',
                  value: start == null
                      ? '未设置'
                      : DateFormat('yyyy.MM.dd').format(start),
                  onTap: () => _pickSemesterStart(context, store),
                ),
              ],
            ),
          ),
          if (schedule != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${schedule.semester} · ${DateFormat('M-d HH:mm').format(schedule.fetchedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '桌面组件',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: scheme.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              children: [
                _WidgetActionRow(
                  icon: Icons.calendar_month_outlined,
                  label: '今日课表组件',
                  onTap: () => _pinWidget(context, schedule: true),
                ),
                const Divider(indent: 66, endIndent: 18),
                _WidgetActionRow(
                  icon: Icons.bolt_outlined,
                  label: '寝室电费组件',
                  onTap: () => _pinWidget(context, schedule: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: TextButton(
              onPressed: () => _checkUpdate(context),
              child: const Text('newclass 1.0.4 · 检查更新'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAccount(
    BuildContext context,
    SettingsStore store,
  ) async {
    final value = await _showTextEditor(
      context,
      title: '教务账号',
      initial: store.account,
      validator: (value) => value.trim().isEmpty ? '请输入教务账号' : null,
    );
    if (value == null || !context.mounted) return;
    final widgets = context.read<WidgetPublisher>();
    await store.updateAccount(value);
    await widgets.publishSchedule(
      schedule: store.schedule,
      semesterStart: store.semesterStart,
    );
  }

  Future<void> _editPassword(
    BuildContext context,
    SettingsStore store,
  ) async {
    final value = await _showTextEditor(
      context,
      title: '密码',
      initial: '',
      obscure: true,
      hint: '输入新密码',
      validator: (value) => value.isEmpty ? '请输入密码' : null,
    );
    if (value == null || !context.mounted) return;
    await store.updatePassword(value);
  }

  Future<void> _editRoom(BuildContext context, SettingsStore store) async {
    final value = await _showTextEditor(
      context,
      title: '宿舍房间号',
      initial: store.roomNo,
      hint: '2620',
      numeric: true,
      validator: (value) =>
          SettingsStore.isValidRoomNo(value) ? null : '房间号应为 3-6 位数字',
    );
    if (value == null || !context.mounted) return;
    if (value == store.roomNo) return;
    final widgets = context.read<WidgetPublisher>();
    await store.updateRoomNo(value);
    await store.clearBalance();
    await widgets.publishElectricity(null);
    await widgets.publishSchedule(
      schedule: store.schedule,
      semesterStart: store.semesterStart,
    );
  }

  Future<void> _pickSemesterStart(
    BuildContext context,
    SettingsStore store,
  ) async {
    final now = DateTime.now();
    final initial = store.semesterStart ?? SemesterCalendar.mondayOf(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '开学日期',
    );
    if (picked == null || !context.mounted) return;
    final widgets = context.read<WidgetPublisher>();
    await store.setSemesterStart(picked);
    await widgets.publishSchedule(
      schedule: store.schedule,
      semesterStart: store.semesterStart,
    );
  }

  Future<void> _pinWidget(
    BuildContext context, {
    required bool schedule,
  }) async {
    final widgets = context.read<WidgetPublisher>();
    final pinned = schedule
        ? await widgets.pinSchedule()
        : await widgets.pinElectricity();
    if (!context.mounted) return;
    if (pinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已请求添加；若没有弹窗，请允许「桌面快捷方式」权限后重试'),
          action: SnackBarAction(
            label: '设置',
            onPressed: _openAppSettings,
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加组件'),
        content: const SingleChildScrollView(
          child: Text(
            '当前桌面未接受应用内添加请求。\n\n'
            '小米/Redmi：应用信息 → 权限管理 → 特殊权限 → '
            '桌面快捷方式，允许后重试。\n\n'
            '也可以手动添加：长按桌面空白处 → 添加小部件 → '
            'newclass → 今日课表/寝室电费。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openAppSettings();
            },
            child: const Text('打开应用设置'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    try {
      await _nativeChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = UpdateService();
    try {
      final info = await service.check();
      if (!context.mounted) return;
      if (info == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
      } else {
        await showUpdateDialog(context, info);
      }
    } on UpdateException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('检查更新失败')),
      );
    } finally {
      service.close();
    }
  }

  Future<String?> _showTextEditor(
    BuildContext context, {
    required String title,
    required String initial,
    String? hint,
    bool obscure = false,
    bool numeric = false,
    required String? Function(String value) validator,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TextEditSheet(
        title: title,
        initial: initial,
        hint: hint,
        obscure: obscure,
        numeric: numeric,
        validator: validator,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetActionRow extends StatelessWidget {
  const _WidgetActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              size: 22,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.initial,
    required this.obscure,
    required this.numeric,
    required this.validator,
    this.hint,
  });

  final String title;
  final String initial;
  final String? hint;
  final bool obscure;
  final bool numeric;
  final String? Function(String value) validator;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => widget.validator(_controller.text) == null;

  void _submit() {
    final error = widget.validator(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscure,
            keyboardType: widget.numeric ? TextInputType.number : null,
            inputFormatters: widget.numeric
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ]
                : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _valid ? _submit : null,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
