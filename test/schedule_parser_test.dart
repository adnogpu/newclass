import 'package:flutter_test/flutter_test.dart';
import 'package:newclass/core/models/schedule_data.dart';
import 'package:newclass/core/schedule/schedule_parser.dart';

const _html = r'''
<html><body>
<select name="xnxq01id">
  <option value="2025-2026-2">上学期</option>
  <option value="2026-2027-1" selected="selected">本学期</option>
</select>
<select name="kbjcmsid">
  <option value="MODE123" selected="selected">时间模式</option>
</select>
<select name="zc">
  <option value="">全部</option>
  <option value="12" selected="selected">12</option>
</select>
<table id="kbtable">
  <tr>
    <th>节次</th><th>星期一</th><th>星期二</th><th>星期三</th><th>星期四</th>
    <th>星期五</th><th>星期六</th><th>星期日</th>
  </tr>
  <tr>
    <th>1,2节 08:00-09:40</th>
    <td>
      <div class="kbcontent">高等数学A(1)<br>
        <font title="老师">张三</font><br>
        <font title="周次(节次)">6-8(周)[01-02节]</font><br>
        <font title="教室">2213</font>
      </div>
      <div class="kbcontent1">高等数学A(1)</div>
    </td>
    <td>
      <div class="kbcontent">C程序设计<font color="red">P</font><br>
        <font title="老师">李四</font><br>
        <font title="周次(节次)">7(周)[01-02节]</font><br>
        <font title="教室">4305</font>
      </div>
    </td>
    <td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>3,4节 09:55-11:35</th>
    <td>
      <div class="kbcontent">课程A<br>
        <font title="老师">王五</font><br>
        <font title="周次(节次)">1-4(单周)[03-04节]</font><br>
        <font title="教室">A101</font><br>
        ----------------------<br>
        课程B<br>
        <font title="老师">赵六</font><br>
        <font title="周次(节次)">2-4(双周)[03-04节]</font><br>
        <font title="教室">B202</font>
      </div>
    </td>
    <td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <th>备注</th>
    <td colspan="7">备注: 军事训练 王健 2-3周;</td>
  </tr>
</table>
</body></html>
''';

void main() {
  test('parses the timetable HTML structure', () {
    final data = ScheduleParser.parse(
      _html,
      fetchedAt: DateTime(2026, 11, 25, 18, 12),
    );

    expect(data.semester, '2026-2027-1');
    expect(data.timeModeId, 'MODE123');
    expect(data.currentWeekHint, 12);
    expect(data.weekdays.length, 7);
    expect(data.weekdays.first, '星期一');
    expect(data.fetchedAt, DateTime(2026, 11, 25, 18, 12));

    expect(data.slots.length, 2);
    expect(data.slots.first.label, '1,2节');
    expect(data.slots.first.sections, [1, 2]);
    expect(data.slots.first.timeRange, '08:00-09:40');

    expect(data.courses.length, 4);
    final math = data.courses.firstWhere((c) => c.name == '高等数学A(1)');
    expect(math.day, 1);
    expect(math.teacher, '张三');
    expect(math.room, '2213');
    expect(math.sections, [1, 2]);
    expect(math.weeks, [6, 7, 8]);
    expect(math.flag, '');
    expect(math.rawWeeks, '6-8(周)[01-02节]');
    expect(math.rawPeriod, '[01-02节]');

    final c = data.courses.firstWhere((c) => c.name == 'C程序设计');
    expect(c.day, 2);
    expect(c.flag, 'P');
    expect(c.weeks, [7]);

    final courseA = data.courses.firstWhere((c) => c.name == '课程A');
    expect(courseA.weeks, [1, 3]);
    expect(courseA.sections, [3, 4]);

    final courseB = data.courses.firstWhere((c) => c.name == '课程B');
    expect(courseB.weeks, [2, 4]);

    expect(data.notes.single, '军事训练 王健 2-3周;');
    expect(
      data.coursesFor(week: 7, day: 1).map((c) => c.name),
      contains('高等数学A(1)'),
    );
    expect(
      data.coursesFor(week: 9, day: 1).map((c) => c.name),
      isNot(contains('高等数学A(1)')),
    );
  });

  test('throws when the timetable table is missing', () {
    expect(
      () => ScheduleParser.parse('<html><body>login</body></html>'),
      throwsA(isA<ScheduleParseException>()),
    );
  });

  test('default semester start matches the current term', () {
    expect(
      SemesterCalendar.defaultStart('2026-2027-1'),
      DateTime(2026, 9, 7),
    );
    expect(
      SemesterCalendar.defaultStart('2026-2027-2'),
      DateTime(2027, 2, 22),
    );
    expect(
      SemesterCalendar.weekForDate(
        DateTime(2026, 11, 25),
        DateTime(2026, 9, 7),
      ),
      12,
    );
  });
}
