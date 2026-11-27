import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/core/models/course.dart';
import 'package:newclass/core/models/schedule_data.dart';
import 'package:newclass/core/models/electricity_balance.dart';
import 'package:newclass/core/models/room_ref.dart';
import 'package:newclass/core/widgets/widget_data.dart';

ScheduleData _schedule() => ScheduleData(
  semester: '2026-2027-1',
  timeModeId: 'MODE',
  weekdays: ScheduleData.weekdayNames,
  slots: const [
    ScheduleSlot(label: '1,2节', sections: [1, 2], timeRange: '08:00-09:40'),
    ScheduleSlot(label: '3,4节', sections: [3, 4], timeRange: '09:55-11:35'),
  ],
  courses: const [
    Course(
      name: '示例课程',
      day: 3,
      sections: [1, 2],
      weeks: [12],
      room: '2213',
      teacher: '示例老师',
      timeLabel: '1,2节',
      timeRange: '08:00-09:40',
    ),
    Course(
      name: '旧课程',
      day: 3,
      sections: [3, 4],
      weeks: [1],
      room: '1101',
      timeLabel: '3,4节',
    ),
  ],
  notes: const [],
  fetchedAt: DateTime(2026, 11, 25, 18, 12),
);

void main() {
  test('schedule widget exposes the full cache and current week', () {
    final data = ScheduleWidgetData.build(
      schedule: _schedule(),
      semesterStart: DateTime(2026, 9, 7),
      now: DateTime(2026, 11, 25, 10),
    );
    expect(data['state'], 'synced');
    expect(data['semester'], '2026-2027-1');
    expect(data['semesterStart'], '2026-09-07');
    expect(data['week'], 12);
    final courses = data['courses'] as List;
    expect(courses.length, 2);
    final first = courses.first as Map;
    expect(first['name'], '示例课程');
    expect(first['day'], 3);
    expect(first['time'], '1,2节');
    expect(first['section'], '1,2节');
    expect(first['startTime'], '08:00');
    expect(first['endTime'], '09:40');
    expect(first['weeks'], [12]);
  });

  test('unsynced schedule widget has an explicit state', () {
    final data = ScheduleWidgetData.build(
      schedule: null,
      semesterStart: null,
      now: DateTime(2026, 11, 25),
    );
    expect(data, {'state': 'unsynced'});
  });

  test('electricity widget formats degree, room and time', () {
    const room = RoomRef(
      roomNo: '2620',
      sysid: 'S1',
      areaid: 'A1',
      districtid: 'D1',
      buildid: 'B2',
      floorid: 'F6',
      roomid: 'R2620',
      roomName: '2620室',
      buildName: '2号学生公寓',
      floorName: '6楼',
    );
    final data = ElectricityWidgetData.build(
      ElectricityBalance(
        degree: '77.52001953125',
        fetchedAt: DateTime(2026, 11, 25, 14, 32),
        room: room,
      ),
    );
    expect(data['state'], 'ok');
    expect(data['degree'], '77.52');
    expect(data['room'], '2号学生公寓 · 6楼 · 2620室');
    expect(data['updated'], '14:32');
  });

  test('electricity widget has an empty state', () {
    final data = ElectricityWidgetData.build(null);
    expect(data['state'], 'none');
    expect(data['degree'], '—');
  });
}
