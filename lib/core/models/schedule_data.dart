import 'course.dart';

class ScheduleSlot {
  const ScheduleSlot({
    required this.label,
    required this.sections,
    required this.timeRange,
  });

  final String label;
  final List<int> sections;
  final String timeRange;

  Map<String, dynamic> toJson() => {
    'label': label,
    'sections': sections,
    'timeRange': timeRange,
  };

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) => ScheduleSlot(
    label: '${json['label'] ?? ''}',
    sections: (json['sections'] as List? ?? const [])
        .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
        .whereType<int>()
        .toList(growable: false),
    timeRange: '${json['timeRange'] ?? ''}',
  );
}

class ScheduleData {
  const ScheduleData({
    required this.semester,
    required this.timeModeId,
    required this.weekdays,
    required this.slots,
    required this.courses,
    required this.notes,
    required this.fetchedAt,
    this.currentWeekHint,
  });

  static const weekdayNames = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  final String semester;
  final String timeModeId;
  final List<String> weekdays;
  final List<ScheduleSlot> slots;
  final List<Course> courses;
  final List<String> notes;
  final DateTime fetchedAt;
  final int? currentWeekHint;

  int get maxWeek {
    var max = 0;
    for (final course in courses) {
      for (final week in course.weeks) {
        if (week > max) max = week;
      }
    }
    return max == 0 ? 20 : max;
  }

  List<Course> coursesFor({required int week, int? day}) => courses
      .where(
        (course) =>
            (course.weeks.isEmpty || course.weeks.contains(week)) &&
            (day == null || course.day == day),
      )
      .toList(growable: false);

  Map<String, dynamic> toJson() => {
    'semester': semester,
    'timeModeId': timeModeId,
    'weekdays': weekdays,
    'slots': slots.map((slot) => slot.toJson()).toList(),
    'courses': courses.map((course) => course.toJson()).toList(),
    'notes': notes,
    'fetchedAt': fetchedAt.toIso8601String(),
    if (currentWeekHint != null) 'currentWeekHint': currentWeekHint,
  };

  factory ScheduleData.fromJson(Map<String, dynamic> json) => ScheduleData(
    semester: '${json['semester'] ?? ''}',
    timeModeId: '${json['timeModeId'] ?? ''}',
    weekdays: (json['weekdays'] as List? ?? const [])
        .map((item) => '$item')
        .toList(growable: false),
    slots: (json['slots'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ScheduleSlot.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    courses: (json['courses'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Course.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
    notes: (json['notes'] as List? ?? const [])
        .map((item) => '$item')
        .toList(growable: false),
    fetchedAt:
        DateTime.tryParse('${json['fetchedAt'] ?? ''}') ?? DateTime.now(),
    currentWeekHint: (json['currentWeekHint'] as num?)?.toInt(),
  );
}

class SemesterCalendar {
  const SemesterCalendar._();

  /// Fall term starts around the first Monday on/after Sep 5, spring term
  /// around the first Monday on/after Feb 20. It can be overridden in settings.
  static DateTime defaultStart(String semester) {
    final match = RegExp(r'^(\d{4})-(\d{4})-([12])$').firstMatch(semester);
    if (match == null) return mondayOf(DateTime.now());
    final year = int.parse(match.group(1)!);
    final term = match.group(3)!;
    final base = term == '1' ? DateTime(year, 9, 5) : DateTime(year + 1, 2, 20);
    return mondayOnOrAfter(base);
  }

  static DateTime mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime mondayOnOrAfter(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final delta = (DateTime.monday - day.weekday) % 7;
    return day.add(Duration(days: delta));
  }

  static DateTime startOfWeek(DateTime semesterStart, int week) {
    return mondayOf(semesterStart).add(Duration(days: (week - 1) * 7));
  }

  static int weekForDate(DateTime date, DateTime semesterStart) {
    final start = mondayOf(semesterStart);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(start).inDays;
    if (diff < 0) return 1;
    return diff ~/ 7 + 1;
  }
}
