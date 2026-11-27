import 'dart:convert';

import '../models/course.dart';
import '../models/electricity_balance.dart';
import '../models/schedule_data.dart';
import 'widget_bridge.dart';

class ScheduleWidgetData {
  const ScheduleWidgetData._();

  static Map<String, dynamic> build({
    required ScheduleData? schedule,
    required DateTime? semesterStart,
    required DateTime now,
  }) {
    if (schedule == null) {
      return {'state': 'unsynced'};
    }
    final start = semesterStart ?? SemesterCalendar.defaultStart(schedule.semester);
    final week = SemesterCalendar.weekForDate(now, start);
    return {
      'state': 'synced',
      'semester': schedule.semester,
      'semesterStart': _isoDate(start),
      'week': week,
      'courses': schedule.courses
          .map(
            (course) => {
              'name': course.name,
              'room': course.room,
              'day': course.day,
              'start': course.startSection,
              'end': course.endSection,
              'section': course.timeLabel,
              'time': course.timeLabel.isNotEmpty
                  ? course.timeLabel
                  : course.timeRange,
              'startTime': _startTime(course.timeRange),
              'endTime': _endTime(course.timeRange),
              'weeks': course.weeks,
            },
          )
          .toList(),
    };
  }

  static String _startTime(String timeRange) {
    final parts = timeRange.split('-');
    if (parts.length != 2) return '';
    final start = parts[0].trim();
    return RegExp(r'^\d{1,2}:\d{2}$').hasMatch(start) ? start : '';
  }

  static String _endTime(String timeRange) {
    final parts = timeRange.split('-');
    if (parts.length != 2) return '';
    final end = parts[1].trim();
    return RegExp(r'^\d{1,2}:\d{2}$').hasMatch(end) ? end : '';
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class ElectricityWidgetData {
  const ElectricityWidgetData._();

  static Map<String, dynamic> build(ElectricityBalance? balance) {
    if (balance == null) {
      return {
        'state': 'none',
        'degree': '—',
        'room': '',
        'build': '',
        'floor': '',
        'roomName': '',
        'updated': '',
      };
    }
    final fetchedAt = balance.fetchedAt;
    final hour = fetchedAt.hour.toString().padLeft(2, '0');
    final minute = fetchedAt.minute.toString().padLeft(2, '0');
    return {
      'state': 'ok',
      'degree': balance.displayDegree,
      'room': balance.room?.displayName ?? '',
      'build': balance.room?.buildName ?? '',
      'floor': balance.room?.floorName ?? '',
      'roomName': balance.room?.roomName ?? '',
      'updated': '$hour:$minute',
    };
  }
}

class WidgetPublisher {
  WidgetPublisher({this.enabled = true});

  static const scheduleKey = 'today_schedule_json';
  static const electricityKey = 'electricity_json';
  static const scheduleProvider = 'TodayScheduleWidgetProvider';
  static const electricityProvider = 'ElectricityWidgetProvider';
  static const androidPackage = 'com.adnogpu.newclass';

  final bool enabled;

  Future<void> publishSchedule({
    required ScheduleData? schedule,
    required DateTime? semesterStart,
    DateTime? now,
  }) => _publish(
    scheduleKey,
    ScheduleWidgetData.build(
      schedule: schedule,
      semesterStart: semesterStart,
      now: now ?? DateTime.now(),
    ),
    scheduleProvider,
  );

  Future<void> publishElectricity(ElectricityBalance? balance) => _publish(
    electricityKey,
    ElectricityWidgetData.build(balance),
    electricityProvider,
  );

  Future<void> publishAll({
    required ScheduleData? schedule,
    required DateTime? semesterStart,
    ElectricityBalance? balance,
    DateTime? now,
  }) async {
    await publishSchedule(
      schedule: schedule,
      semesterStart: semesterStart,
      now: now,
    );
    await publishElectricity(balance);
  }

  Future<bool> pinSchedule() => _pin(scheduleProvider);

  Future<bool> pinElectricity() => _pin(electricityProvider);

  Future<bool> _pin(String provider) async {
    if (!enabled) return false;
    try {
      return await requestWidgetPin(
        provider: provider,
        qualifiedProvider: '$androidPackage.widget.$provider',
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _publish(
    String key,
    Map<String, dynamic> data,
    String provider,
  ) async {
    if (!enabled) return;
    try {
      await publishWidgetData(
        key: key,
        data: jsonEncode(data),
        provider: provider,
        qualifiedProvider: '$androidPackage.widget.$provider',
      );
    } catch (_) {
      // Widgets are optional; never break the app because of them.
    }
  }
}

List<Course> coursesForWidget(ScheduleData schedule, int week, int day) {
  return schedule
      .coursesFor(week: week, day: day)
      .toList(growable: false)
    ..sort((a, b) => a.startSection.compareTo(b.startSection));
}
