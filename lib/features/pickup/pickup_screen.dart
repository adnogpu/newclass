import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/pickup_api.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  static const _orderKey = 'pickup_order_sn';

  final TextEditingController _controller = TextEditingController();
  final PickupApi _api = PickupApi();
  PickupResult? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _restoreOrder();
  }

  Future<void> _restoreOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_orderKey) ?? '';
      if (!mounted || saved.isEmpty) return;
      if (_controller.text.isEmpty) {
        setState(() => _controller.text = saved);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _query() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final order = _controller.text.trim();
    if (order.isEmpty) {
      setState(() => _error = '请输入订单号');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _api.query(order);
      if (!mounted) return;
      setState(() => _result = result);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_orderKey, order);
      } catch (_) {}
    } on PickupException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '查询失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Row(
            children: [
              Text(
                '外卖柜查询',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
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
                  tooltip: '查询',
                  onPressed: _query,
                  icon: const Icon(Icons.search_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  maxLength: 32,
                  onSubmitted: (_) => _query(),
                  decoration: InputDecoration(
                    labelText: '订单号',
                    counterText: '',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: () {
                              _controller.clear();
                              setState(() => _result = null);
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _query,
                  icon: const Icon(Icons.local_shipping_outlined, size: 20),
                  label: const Text('查询'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorCard(message: _error!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 14),
            _PickupResultCard(result: _result!),
          ] else if (_error == null) ...[
            const SizedBox(height: 56),
            _EmptyState(color: scheme),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});

  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: color.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 30,
            color: color.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '输入订单号查询取餐信息',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupResultCard extends StatelessWidget {
  const _PickupResultCard({required this.result});

  final PickupResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (result.isElsewhere) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(
              label: '在其他柜机',
              background: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
            ),
            const SizedBox(height: 18),
            Text(
              result.otherCabinet,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '请前往该智能柜取餐',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final cabinet = result.cabinet;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cabinet?.name.isNotEmpty == true
                      ? cabinet!.name
                      : '取餐柜',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              _statusChip(scheme),
            ],
          ),
          if (result.pickedUp) ...[
            const SizedBox(height: 18),
            Text(
              '外卖已取走',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ] else if (result.inCabinet) ...[
            const SizedBox(height: 26),
            Text(
              '取件码',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  result.pickupCode.isEmpty ? '—' : result.pickupCode,
                  style: TextStyle(
                    fontSize: 48,
                    height: 1,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                if (result.pickupCode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '复制取件码',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: result.pickupCode),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('取件码已复制')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ],
          if (result.saved == null) ...[
            const SizedBox(height: 18),
            Text(
              '订单状态未知',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (cabinet != null) ...[
            const SizedBox(height: 22),
            _DetailRow(
              icon: Icons.sensor_door_outlined,
              label: '柜门',
              value: cabinet.box.isEmpty ? '—' : cabinet.box,
            ),
            if (cabinet.scene.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cabinet.scene,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusChip(ColorScheme scheme) {
    if (result.pickedUp) {
      return _StatusChip(
        label: '已取走',
        background: scheme.surfaceContainerHigh,
        foreground: scheme.onSurfaceVariant,
      );
    }
    if (result.inCabinet) {
      return _StatusChip(
        label: '在柜中',
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    }
    return _StatusChip(
      label: '状态未知',
      background: scheme.surfaceContainerHigh,
      foreground: scheme.onSurfaceVariant,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
