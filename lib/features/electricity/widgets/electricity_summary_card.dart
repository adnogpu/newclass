import 'package:material_ui/material_ui.dart';

import '../../../core/models/electricity_balance.dart';
import '../../../core/models/room_ref.dart';
import '../../../core/ui/app_ui.dart';

class ElectricitySummaryCard extends StatelessWidget {
  const ElectricitySummaryCard({
    super.key,
    required this.balance,
    required this.room,
    required this.roomLabel,
    required this.updatedLabel,
  });

  final ElectricityBalance? balance;
  final RoomRef? room;
  final String roomLabel;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      gradient: AppGradients.card,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 58,
              child: CustomPaint(
                painter: _CardWavePainter(
                  color: scheme.primary.withValues(alpha: 0.10),
                ),
              ),
            ),
          Positioned(
            right: -42,
            top: -56,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.16),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7CC8FF).withValues(alpha: 0.18),
                    const Color(0xFF7CC8FF).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.primary,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '寝室电费',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '实时用电情况 · 省电从我做起',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) =>
                          AppGradients.primary.createShader(bounds),
                      child: Text(
                        balance?.displayDegree ?? '—',
                        style: const TextStyle(
                          fontSize: 58,
                          height: 0.95,
                          letterSpacing: -2.2,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 7, bottom: 6),
                      child: Text(
                        '度',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _RoomPill(room: room, roomLabel: roomLabel),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      updatedLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _CardWavePainter extends CustomPainter {
  const _CardWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height * 0.52)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.18,
        size.width * 0.38,
        size.height * 0.86,
        size.width * 0.58,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.24,
        size.width * 0.9,
        size.height * 0.62,
        size.width,
        size.height * 0.38,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
    final second = Paint()..color = color.withValues(alpha: 0.55);
    final path2 = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.48,
        size.width * 0.42,
        size.height * 0.96,
        size.width * 0.64,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.48,
        size.width * 0.92,
        size.height * 0.7,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, second);
  }

  @override
  bool shouldRepaint(covariant _CardWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RoomPill extends StatelessWidget {
  const _RoomPill({required this.room, required this.roomLabel});

  final RoomRef? room;
  final String roomLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = roomLabel
        .split('·')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final build = room?.buildName.isNotEmpty == true
        ? room!.buildName
        : (parts.isNotEmpty ? parts.first : roomLabel);
    final floor = room?.floorName.isNotEmpty == true
        ? room!.floorName
        : (parts.length > 1 ? parts[1] : '');
    final name = room?.roomName.isNotEmpty == true
        ? room!.roomName
        : (parts.length > 2 ? parts[2] : '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.home_outlined,
            size: 16,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              build.isEmpty ? '未设置房间' : build,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          if (floor.isNotEmpty) ...[
            const _Divider(),
            Icon(
              Icons.layers_outlined,
              size: 13,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                floor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          if (name.isNotEmpty) ...[
            const _Divider(),
            Icon(
              Icons.bed_outlined,
              size: 13,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
