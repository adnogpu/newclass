import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../core/update/apk_installer.dart';
import '../../data/update_service.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      final started = await downloadAndInstallApk(
        widget.info,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      if (started) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = '当前设备不支持自动安装');
      }
    } on UpdateException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '下载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = widget.info;
    final sizeLabel = info.size > 0
        ? ' · ${info.sizeMb.toStringAsFixed(1)} MB'
        : '';
    return AlertDialog(
      title: Text('发现新版本 ${info.versionName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '构建 ${info.versionCode}$sizeLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '更新内容',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ..._noteWidgets(context, info.notes),
            if (_downloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress == null
                    ? '正在下载…'
                    : '下载中 ${(_progress! * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: _downloading ? null : _install,
          child: Text(_downloading ? '下载中' : '下载并安装'),
        ),
      ],
    );
  }
}

List<Widget> _noteWidgets(BuildContext context, String notes) {
  final scheme = Theme.of(context).colorScheme;
  final lines = const LineSplitter()
      .convert(notes)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return [
      Text(
        '本次更新包含界面优化和问题修复。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    ];
  }
  final widgets = <Widget>[];
  for (final line in lines) {
    if (line.startsWith('###')) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 8));
      widgets.add(
        Text(
          line.replaceFirst(RegExp(r'^#+\s*'), ''),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      continue;
    }
    final text = line.replaceFirst(RegExp(r'^[-*]\s*'), '');
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return widgets;
}
