import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/course.dart';
import '../../core/models/schedule_data.dart';
import '../../core/storage/settings_store.dart';
import '../../data/captcha_ocr.dart';
import '../../data/schedule_api.dart';
import '../../data/schedule_service.dart';
import '../../theme/app_theme.dart';
import 'captcha_sheet.dart';

double scheduleCourseLeft({
  required int day,
  required double dayWidth,
  required int column,
  required int columns,
}) =>
    (day - 1) * dayWidth + column * (dayWidth / columns) + 2;

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _axisWidth = 46.0;
  static const _minRowHeight = 82.0;
  static const _maxRowHeight = 160.0;
  static const _minDayWidth = 60.0;
  static const _headerHeight = 56.0;
  static const _fallbackSlots = [
    ScheduleSlot(label: '1,2节', sections: [1, 2], timeRange: ''),
    ScheduleSlot(label: '3,4节', sections: [3, 4], timeRange: ''),
    ScheduleSlot(label: '5,6节', sections: [5, 6], timeRange: ''),
    ScheduleSlot(label: '7,8节', sections: [7, 8], timeRange: ''),
    ScheduleSlot(label: '9,10节', sections: [9, 10], timeRange: ''),
  ];

  late final SettingsStore _store;
  late final ScheduleService _scheduleService;
  final ScrollController _dayScrollController = ScrollController();
  int _week = 1;
  bool _syncing = false;
  bool _showToday = false;
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
    _dayScrollController.dispose();
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
      if (data == null && CaptchaOcr.isSupported) {
        // The bundled OCR model handles this CAPTCHA reliably. If a challenge
        // is unreadable or rejected, fetch a fresh one instead of asking the
        // user to solve arithmetic in the middle of a login.
        for (var attempt = 0; attempt < 6 && data == null; attempt++) {
          if (!mounted) return;
          final challenge = await _scheduleService.fetchCaptcha();
          final answer = await CaptchaOcr.solve(challenge.imageBytes);
          if (answer == null) continue;
          try {
            data = await _scheduleService.loginAndSync(
              challenge: challenge,
              answer: '$answer',
            );
          } on CaptchaRejectedException {
            continue;
          }
        }
        if (data == null) {
          _snack('验证码自动识别失败，请重试');
          return;
        }
      } else if (data == null) {
        var challenge = await _scheduleService.fetchCaptcha();
        String? notice;
        while (mounted && data == null) {
          if (!mounted) return;
          final answer = await showCaptchaSheet(
            context,
            challenge,
            notice: notice,
          );
          if (answer == null) return;
          try {
            data = await _scheduleService.loginAndSync(
              challenge: challenge,
              answer: '$answer',
            );
          } on CaptchaRejectedException {
            notice = '验证码错误，请重新输入';
            challenge = await _scheduleService.fetchCaptcha();
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
        final accent = _courseAccent(sheetContext, course.name);
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
                        color: accent,
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

  Color _courseAccent(BuildContext context, String name) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = dark
        ? AppColors.courseAccentsDark
        : AppColors.courseAccentsLight;
    return palette[name.hashCode.abs() % palette.length];
  }

  Color _courseBackground(ColorScheme scheme, Color accent) {
    final alpha = scheme.brightness == Brightness.dark ? 0.16 : 0.10;
    return Color.alphaBlend(
      accent.withValues(alpha: alpha),
      scheme.surfaceContainerLowest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currentWeek = _store.hasSchedule ? _store.currentWeek(now) : 1;
    final weekStart = _weekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final format = DateFormat('M.d');
    final range = '${format.format(weekStart)} – ${format.format(weekEnd)}';
    final hasSchedule = _store.hasSchedule;
    final todayCourses =
        (_store.schedule?.coursesFor(
                  week: currentWeek,
                  day: now.weekday,
                ) ??
                const <Course>[])
            .toList()
          ..sort((a, b) => a.startSection.compareTo(b.startSection));
    const weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateLabel =
        '${DateFormat('M月d日').format(now)} ${weekdayLabels[now.weekday - 1]}';

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Row(
              children: [
                Text(
                  _showToday ? '今日' : '课表',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showToday = !_showToday),
                  icon: Icon(
                    _showToday
                        ? Icons.calendar_view_week_rounded
                        : Icons.view_agenda_rounded,
                    size: 18,
                  ),
                  label: Text(_showToday ? '本周' : '今日'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                  ),
                ),
                const SizedBox(width: 2),
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
          if (_showToday) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '第$currentWeek周',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (hasSchedule)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${todayCourses.length} 门',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildToday(context, now, todayCourses)),
          ] else ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasSchedule) ...[
                            Text(
                              '第$_week周',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            range,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
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
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: _buildGrid(context, weekStart),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToday(
    BuildContext context,
    DateTime now,
    List<Course> courses,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (!_store.hasSchedule) {
      return Center(
        child: FilledButton.tonal(
          onPressed: _sync,
          child: const Text('同步课表'),
        ),
      );
    }
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 38,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              '今天没有课程',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TodayCourseTile(
            course: course,
            accent: _courseAccent(context, course.name),
            now: now,
            onTap: () => _showCourse(course),
          ),
        );
      },
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
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final dayWidth = math.max(
            _minDayWidth,
            (availableWidth - _axisWidth) / 7,
          );
          final availableHeight =
              constraints.hasBoundedHeight && constraints.maxHeight > 0
              ? constraints.maxHeight - _headerHeight
              : _minRowHeight * slots.length;
          final rowHeight = math.max(
            _minRowHeight,
            math.min(_maxRowHeight, availableHeight / slots.length),
          );
          final totalHeight = rowHeight * slots.length;
          final dayAreaWidth = dayWidth * 7;

          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _axisWidth,
                  child: Column(
                    children: [
                      Container(
                        height: _headerHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final slot in slots)
                        _TimeAxisCell(slot: slot, height: rowHeight),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _dayScrollController,
                    child: SingleChildScrollView(
                      controller: _dayScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: dayAreaWidth,
                        child: Column(
                          children: [
                            Container(
                              height: _headerHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: scheme.outlineVariant.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                              ),
                              child: _WeekdayHeader(
                                weekStart: weekStart,
                                dayWidth: dayWidth,
                              ),
                            ),
                            SizedBox(
                              height: totalHeight,
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
                                        color: scheme.primary.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                  for (final item in placed)
                                    Positioned(
                                      left: scheduleCourseLeft(
                                        day: item.day,
                                        dayWidth: dayWidth,
                                        column: item.column,
                                        columns: item.columns,
                                      ),
                                      top: item.start * rowHeight + 3,
                                      width: dayWidth / item.columns - 4,
                                      height:
                                          (item.end - item.start + 1) *
                                              rowHeight -
                                          6,
                                      child: _CourseCard(
                                        course: item.course,
                                        accent: _courseAccent(
                                          context,
                                          item.course.name,
                                        ),
                                        background: _courseBackground(
                                          scheme,
                                          _courseAccent(
                                            context,
                                            item.course.name,
                                          ),
                                        ),
                                        compact:
                                            (item.end - item.start + 1) *
                                                rowHeight <
                                            58,
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
                    ),
                  ),
                ),
              ],
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
  const _WeekdayHeader({required this.weekStart, required this.dayWidth});

  final DateTime weekStart;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        final isToday =
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        return SizedBox(
          width: dayWidth,
          child: Center(
            child: _isTodayContainer(
              isToday: isToday,
              scheme: scheme,
              label: labels[index],
              day: date.day,
            ),
          ),
        );
      }),
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
      width: double.infinity,
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
    required this.accent,
    required this.background,
    required this.compact,
    required this.onTap,
  });

  final Course course;
  final Color accent;
  final Color background;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: accent.withValues(alpha: 0.24),
          width: 0.8,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          course.name,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 3 : 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (!compact && course.room.isNotEmpty)
                      Text(
                        course.room,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.1,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCourseTile extends StatelessWidget {
  const _TodayCourseTile({
    required this.course,
    required this.accent,
    required this.now,
    required this.onTap,
  });

  final Course course;
  final Color accent;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final times = course.timeRange.split('-');
    final start = times.length == 2 ? times[0].trim() : course.timeLabel;
    final end = times.length == 2 ? times[1].trim() : '';
    final startClock = _clock(start, now);
    final endClock = _clock(end, now);
    final ended = endClock != null && now.isAfter(endClock);
    final current =
        !ended &&
        startClock != null &&
        endClock != null &&
        !now.isBefore(startClock) &&
        now.isBefore(endClock);

    return Opacity(
      opacity: ended ? 0.6 : 1,
      child: Material(
        color: scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 44,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 54,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      if (end.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          end,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (current)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '进行中',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          if (course.room.isNotEmpty) course.room,
                          if (course.teacher.isNotEmpty) course.teacher,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DateTime? _clock(String value, DateTime day) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
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
