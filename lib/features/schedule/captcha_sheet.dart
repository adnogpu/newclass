import 'package:material_ui/material_ui.dart';

import '../../data/schedule_api.dart';

Future<int?> showCaptchaSheet(
  BuildContext context,
  CaptchaChallenge challenge,
) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CaptchaSheet(challenge: challenge),
  );
}

class _CaptchaSheet extends StatefulWidget {
  const _CaptchaSheet({required this.challenge});

  final CaptchaChallenge challenge;

  @override
  State<_CaptchaSheet> createState() => _CaptchaSheetState();
}

class _CaptchaSheetState extends State<_CaptchaSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null) {
      setState(() => _error = '请输入计算结果');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Text('验证码', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Container(
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Image.memory(
              widget.challenge.imageBytes,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '计算结果',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _submit, child: const Text('同步')),
        ],
      ),
    );
  }
}
