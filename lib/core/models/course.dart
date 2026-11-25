class Course {
  const Course({
    required this.name,
    required this.day,
    required this.sections,
    required this.weeks,
    this.teacher = '',
    this.room = '',
    this.rawWeeks = '',
    this.rawPeriod = '',
    this.flag = '',
    this.timeLabel = '',
    this.timeRange = '',
  });

  final String name;
  final String teacher;
  final String room;
  final int day;
  final List<int> sections;
  final List<int> weeks;
  final String rawWeeks;
  final String rawPeriod;
  final String flag;
  final String timeLabel;
  final String timeRange;

  int get startSection =>
      sections.isEmpty ? 0 : sections.reduce((a, b) => a < b ? a : b);

  int get endSection =>
      sections.isEmpty ? 0 : sections.reduce((a, b) => a > b ? a : b);

  String get periodLabel {
    if (sections.isEmpty) return rawPeriod.replaceAll(RegExp(r'[\[\]节]'), '');
    if (startSection == endSection) return '第$startSection节';
    return '第$startSection-$endSection节';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'teacher': teacher,
    'room': room,
    'day': day,
    'sections': sections,
    'weeks': weeks,
    'rawWeeks': rawWeeks,
    'rawPeriod': rawPeriod,
    'flag': flag,
    'timeLabel': timeLabel,
    'timeRange': timeRange,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    name: '${json['name'] ?? ''}',
    teacher: '${json['teacher'] ?? ''}',
    room: '${json['room'] ?? ''}',
    day: (json['day'] as num?)?.toInt() ?? 0,
    sections: _intList(json['sections']),
    weeks: _intList(json['weeks']),
    rawWeeks: '${json['rawWeeks'] ?? ''}',
    rawPeriod: '${json['rawPeriod'] ?? ''}',
    flag: '${json['flag'] ?? ''}',
    timeLabel: '${json['timeLabel'] ?? ''}',
    timeRange: '${json['timeRange'] ?? ''}',
  );

  static List<int> _intList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
        .whereType<int>()
        .toList(growable: false);
  }
}
