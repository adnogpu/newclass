import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/course.dart';
import '../../core/models/schedule_data.dart';
import '../../core/storage/settings_store.dart';
import '../../data/schedule_api.dart';
import '../../data/schedule_service.dart';
import '../../theme/app_theme.dart';
import 'captcha_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _axisWidth = 46.0;
  static const _rowHeight = 88.0;
  static const _fallbackSlots = [
    ScheduleSlot(label: '1,2节', sections: [1, 2], timeRange: ''),
    ScheduleSlot(label: '3,4节', sections: [3, 4], timeRange: ''),
    ScheduleSlot(label: '5,6节', sections: [5, 6], timeRange: ''),
    ScheduleSlot(label: '7,8节', sections: [7, 8], timeRange: ''),
    ScheduleSlot(label: '9,10节', sections: [9, 10], timeRange: ''),
  ];

  late final SettingsStore _store;
  late final ScheduleService _scheduleService;
  int _week = 1;
  bool _syncing = false;
  DateTime? _lastStart;
  DateTime? _lastFetchedAt;

  @override
  void initState() {
    super.initState();
    _store = context.read<SettingsStore>();
    _scheduleService = context.read<ScheduleService>();
    if (_store.hasSchedule) {
      _week = _store.currentWeek(DateTime.now());
    }
    _lastStart = _store.semesterStart;
    _lastFetchedAt = _store.schedule?.fetchedAt;
    _store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final start = _store.semesterStart;
    final fetchedAt = _store.schedule?.fetchedAt;
    var changed = false;
    if (start != _lastStart) {
      _lastStart = start;
      if (_store.hasSchedule) {
        _week = _store.currentWeek(DateTime.now());
      }
      changed = true;
    }
    if (fetchedAt != _lastFetchedAt) {
      _lastFetchedAt = fetchedAt;
      if (fetchedAt != null) {
        _week = _store.currentWeek(DateTime.now());
      }
      changed = true;
    }
    if (changed) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  List<ScheduleSlot> get _slots {
    final slots = _store.schedule?.slots ?? const <ScheduleSlot>[];
    return slots.isEmpty ? _fallbackSlots : slots;
  }

  List<Course> get _weekCourses =>
      _store.schedule?.coursesFor(week: _week) ?? const <Course>[];

  DateTime get _weekStart {
    final monday = SemesterCalendar.mondayOf(DateTime.now());
    final start = _store.semesterStart;
    if (_store.schedule == null || start == null) {
      return monday.add(Duration(days: (_week - 1) * 7));
    }
    return SemesterCalendar.startOfWeek(start, _week);
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    var begun = false;
    try {
      await _scheduleService.begin();
      begun = true;
      ScheduleData? data;
      try {
        data = await _scheduleService.trySilentSync();
      } on ScheduleException catch (error) {
        _snack(error.message);
        return;
      }
      if (data == null) {
        while (mounted) {
          final challenge = await _scheduleService.fetchCaptcha();
          if (!mounted) return;
          final answer = await showCaptchaSheet(context, challenge);
          if (answer == null) return;
          try {
            data = await _scheduleService.loginAndSync(
              challenge: challenge,
              answer: '$answer',
            );
            break;
          } on CaptchaRejectedException {
            _snack('验证码错误，请重试');
          }
        }
      }
      if (data != null) {
        _snack('课表已同步');
      }
    } on LoginException catch (error) {
      _snack(error.message);
    } on ScheduleException catch (error) {
      _snack(error.message);
    } catch (_) {
      _snack('同步失败，请稍后重试');
    } finally {
      if (begun) {
        try {
          await _scheduleService.end();
        } catch (_) {}
      }
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _shiftWeek(int delta) {
    final max = _store.maxWeek;
    final next = (_week + delta).clamp(1, max);
    if (next != _week) setState(() => _week = next);
  }

  Future<void> _pickWeek() async {
    if (!_store.hasSchedule) return;
    final max = _store.maxWeek;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择周次', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(max, (index) {
                    final week = index + 1;
                    final active = week == _week;
                    return SizedBox(
                      width: 48,
                      height: 44,
                      child: Material(
                        color: active
                            ? scheme.primary
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(sheetContext).pop(week),
                          child: Center(
                            child: Text(
                              '$week',
                              style: TextStyle(
                                color: active
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _week = selected);
    }
  }

  void _showCourse(Course course) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final background = _courseColor(sheetContext, course.name);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        course.name,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    if (course.flag == 'P')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '调课',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  text: [
                    course.timeLabel,
                    if (course.timeRange.isNotEmpty) course.timeRange,
                  ].where((e) => e.isNotEmpty).join(' · '),
                ),
                if (course.room.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.place_outlined,
                    text: course.room,
                  ),
                ],
                if (course.teacher.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    text: course.teacher,
                  ),
                ],
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.date_range_outlined,
                  text: _weeksLabel(course.weeks),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _weeksLabel(List<int> weeks) {
    if (weeks.isEmpty) return '周次未知';
    final sorted = [...weeks]..sort();
    if (sorted.length == 1) return '第${sorted.first}周';
    if (sorted.last - sorted.first + 1 == sorted.length) {
      return '第${sorted.first}-${sorted.last}周';
    }
    return '第${sorted.join('、')}周';
  }

  Color _courseColor(BuildContext context, String name) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark
        ? AppColors.coursePaletteDark
        : AppColors.coursePaletteLight;
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weekStart = _weekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final format = DateFormat('M.d');
    final range = '${format.format(weekStart)} – ${format.format(weekEnd)}';
    final hasSchedule = _store.hasSchedule;
    final title = hasSchedule
        ? '第$_week周 · $range'
        : range;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Row(
              children: [
                Text(
                  '课表',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                if (_syncing)
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
                    tooltip: '同步课表',
                    onPressed: _sync,
                    icon: const Icon(Icons.sync_rounded, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WeekArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _shiftWeek(-1),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickWeek,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 9,
                        ),
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    _WeekArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _shiftWeek(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _WeekdayHeader(
              weekStart: weekStart,
              axisWidth: _axisWidth,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: _buildGrid(context, weekStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, DateTime weekStart) {
    final scheme = Theme.of(context).colorScheme;
    final slots = _slots;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final dayOffset = todayDate.difference(startDate).inDays;
    final todayIndex = dayOffset >= 0 && dayOffset < 7 ? dayOffset : -1;
    final courses = _weekCourses;
    final placed = <_PlacedCourse>[];
    for (var day = 1; day <= 7; day++) {
      final dayCourses = courses
          .where((course) => course.day == day)
          .toList(growable: false);
      placed.addAll(_layoutDay(day, dayCourses, slots));
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayWidth = (constraints.maxWidth - _axisWidth) / 7;
          final totalHeight = _rowHeight * slots.length;
          return SingleChildScrollView(
            child: SizedBox(
              height: totalHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _axisWidth,
                    child: Column(
                      children: [
                        for (final slot in slots)
                          _TimeAxisCell(slot: slot, height: _rowHeight),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GridPainter(
                              columns: 7,
                              rows: slots.length,
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ),
                        if (todayIndex >= 0)
                          Positioned(
                            left: todayIndex * dayWidth,
                            top: 0,
                            width: dayWidth,
                            height: totalHeight,
                            child: ColoredBox(
                              color: scheme.primary.withValues(alpha: 0.05),
                            ),
                          ),
                        for (final item in placed)
                          Positioned(
                            left:
                                item.day * dayWidth +
                                item.column * (dayWidth / item.columns) +
                                2,
                            top: item.start * _rowHeight + 3,
                            width: dayWidth / item.columns - 4,
                            height:
                                (item.end - item.start + 1) * _rowHeight - 6,
                            child: _CourseCard(
                              course: item.course,
                              color: _courseColor(context, item.course.name),
                              compact:
                                  (item.end - item.start + 1) * _rowHeight < 58,
                              onTap: () => _showCourse(item.course),
                            ),
                          ),
                        if (_store.schedule == null)
                          Positioned.fill(
                            child: Center(
                              child: _syncing
                                  ? const SizedBox.shrink()
                                  : FilledButton.tonal(
                                      onPressed: _sync,
                                      child: const Text('同步课表'),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_PlacedCourse> _layoutDay(
    int day,
    List<Course> courses,
    List<ScheduleSlot> slots,
  ) {
    if (courses.isEmpty) return const [];
    final entries = courses
        .map(
          (course) => _CourseEntry(
            course,
            _slotIndexFor(course.startSection, slots),
            _slotIndexFor(course.endSection, slots),
          ),
        )
        .toList()
      ..sort((a, b) {
        final start = a.start.compareTo(b.start);
        return start != 0 ? start : a.end.compareTo(b.end);
      });

    final result = <_PlacedCourse>[];
    var cluster = <_CourseEntry>[];
    var clusterEnd = -1;

    void flush() {
      if (cluster.isEmpty) return;
      final columnEnds = <int>[];
      final columns = <int>[];
      for (final entry in cluster) {
        var column = 0;
        while (column < columnEnds.length && columnEnds[column] >= entry.start) {
          column++;
        }
        if (column == columnEnds.length) {
          columnEnds.add(entry.end);
        } else {
          columnEnds[column] = entry.end;
        }
        columns.add(column);
      }
      final columnCount = math.max(1, columnEnds.length);
      for (var index = 0; index < cluster.length; index++) {
        result.add(
          _PlacedCourse(
            day: day,
            course: cluster[index].course,
            start: cluster[index].start,
            end: cluster[index].end,
            column: columns[index],
            columns: columnCount,
          ),
        );
      }
      cluster = <_CourseEntry>[];
    }

    for (final entry in entries) {
      if (cluster.isEmpty || entry.start <= clusterEnd) {
        cluster.add(entry);
        clusterEnd = math.max(clusterEnd, entry.end);
      } else {
        flush();
        clusterEnd = entry.end;
        cluster.add(entry);
      }
    }
    flush();
    return result;
  }

  int _slotIndexFor(int section, List<ScheduleSlot> slots) {
    for (var index = 0; index < slots.length; index++) {
      if (slots[index].sections.contains(section)) return index;
    }
    if (slots.isEmpty) return 0;
    final fallback = section <= 0 ? 0 : ((section - 1) / 2).floor();
    return fallback.clamp(0, slots.length - 1);
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.weekStart, required this.axisWidth});

  final DateTime weekStart;
  final double axisWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        SizedBox(width: axisWidth),
        Expanded(
          child: Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Expanded(
                child: _isTodayContainer(
                  isToday: isToday,
                  scheme: scheme,
                  label: labels[index],
                  day: date.day,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _isTodayContainer({
    required bool isToday,
    required ColorScheme scheme,
    required String label,
    required int day,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isToday ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            color: isToday ? scheme.onPrimaryContainer : scheme.onSurface,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isToday
          ? BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            )
          : null,
      child: content,
    );
  }
}

class _WeekArrow extends StatelessWidget {
  const _WeekArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 40,
        child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _TimeAxisCell extends StatelessWidget {
  const _TimeAxisCell({required this.slot, required this.height});

  final ScheduleSlot slot;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final times = slot.timeRange.split('-');
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.label.replaceAll('节', ''),
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (times.length == 2) ...[
              const SizedBox(height: 3),
              Text(
                times[0],
                style: TextStyle(
                  fontSize: 8,
                  height: 1.1,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              Text(
                times[1],
                style: TextStyle(
                  fontSize: 8,
                  height: 1.1,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.color,
    required this.compact,
    required this.onTap,
  });

  final Course course;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  course.name,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (!compact && course.room.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  course.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.columns,
    required this.rows,
    required this.color,
  });

  final int columns;
  final int rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final rowHeight = size.height / rows;
    for (var row = 1; row < rows; row++) {
      final y = row * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final columnWidth = size.width / columns;
    for (var column = 1; column < columns; column++) {
      final x = column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.rows != rows ||
      oldDelegate.color != color;
}

class _CourseEntry {
  const _CourseEntry(this.course, this.start, this.end);

  final Course course;
  final int start;
  final int end;
}

class _PlacedCourse {
  const _PlacedCourse({
    required this.day,
    required this.course,
    required this.start,
    required this.end,
    required this.column,
    required this.columns,
  });

  final int day;
  final Course course;
  final int start;
  final int end;
  final int column;
  final int columns;
}
