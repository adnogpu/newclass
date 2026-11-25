import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/course.dart';
import '../models/schedule_data.dart';

class ScheduleParseException implements Exception {
  const ScheduleParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleParser {
  const ScheduleParser._();

  static ScheduleData parse(String html, {DateTime? fetchedAt}) {
    final document = html_parser.parse(html);
    final table = document.querySelector('table#kbtable');
    if (table == null) {
      throw const ScheduleParseException('未找到课表表格');
    }

    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) {
      throw const ScheduleParseException('课表为空');
    }

    final headerCells = rows.first.children
        .where((node) => node.localName == 'th' || node.localName == 'td')
        .toList();
    var weekdays = headerCells
        .skip(1)
        .take(7)
        .map((node) => _collapse(node.text))
        .toList();
    if (weekdays.length != 7 || weekdays.any((day) => day.isEmpty)) {
      weekdays = List<String>.from(ScheduleData.weekdayNames);
    }

    final slots = <ScheduleSlot>[];
    final courses = <Course>[];
    final notes = <String>[];

    for (final row in rows.skip(1)) {
      final rowChildren = row.children;
      dom.Element? head;
      for (final node in rowChildren) {
        if (node.localName == 'th') {
          head = node;
          break;
        }
      }
      if (head == null) continue;

      final headText = _collapse(head.text);
      if (!headText.contains('节')) {
        final cells = row.children
            .where((node) => node.localName == 'td')
            .toList();
        final source = cells.isEmpty
            ? row.text
            : cells.map((cell) => cell.text).join(' ');
        final text = _collapse(source).replaceFirst(
          RegExp(r'^备注\s*[:：]\s*'),
          '',
        );
        if (text.isNotEmpty) notes.add(text);
        continue;
      }

      final sectionMatch = RegExp(r'([\d,，]+)\s*节').firstMatch(headText);
      final sections = sectionMatch == null
          ? const <int>[]
          : _expandIntRanges(sectionMatch.group(1)!);
      final timeMatch = RegExp(
        r'(\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2})',
      ).firstMatch(headText);
      final timeRange = timeMatch?.group(1)?.replaceAll(' ', '') ?? '';
      final timeLabel = timeRange.isNotEmpty
          ? headText.split(timeRange).first.trim()
          : headText;
      slots.add(
        ScheduleSlot(
          label: timeLabel,
          sections: sections,
          timeRange: timeRange,
        ),
      );

      final cells = row.children
          .where((node) => node.localName == 'td')
          .take(7)
          .toList();
      for (var index = 0; index < cells.length; index++) {
        final day = index + 1;
        final cell = cells[index];
        final contentDivs = cell.querySelectorAll('div.kbcontent');
        for (final div in contentDivs) {
          if (div.classes.contains('kbcontent1')) continue;
          if (_collapse(div.text).isEmpty) continue;
          final blocks = div.innerHtml.split(RegExp(r'-{3,}'));
          for (final block in blocks) {
            if (block.trim().isEmpty) continue;
            final parsed = _parseBlock(block);
            if (parsed.name.isEmpty) continue;
            courses.add(
              Course(
                name: parsed.name,
                teacher: parsed.teacher,
                room: parsed.room,
                day: day,
                sections: parsed.sections.isEmpty
                    ? sections
                    : parsed.sections,
                weeks: parsed.weeks,
                rawWeeks: parsed.rawWeeks,
                rawPeriod: parsed.rawPeriod,
                flag: parsed.flag,
                timeLabel: timeLabel,
                timeRange: timeRange,
              ),
            );
          }
        }
      }
    }

    return ScheduleData(
      semester: _selectedValue(document, 'xnxq01id'),
      timeModeId: _selectedValue(document, 'kbjcmsid'),
      weekdays: weekdays,
      slots: slots,
      courses: courses,
      notes: notes,
      fetchedAt: fetchedAt ?? DateTime.now(),
      currentWeekHint: int.tryParse(_selectedValue(document, 'zc')),
    );
  }

  static _ParsedBlock _parseBlock(String blockHtml) {
    final fragment = html_parser.parseFragment('<div>$blockHtml</div>');
    dom.Element? wrapper;
    for (final node in fragment.nodes) {
      if (node is dom.Element && node.localName == 'div') {
        wrapper = node;
        break;
      }
    }
    wrapper ??= fragment.children.isNotEmpty ? fragment.children.first : null;
    if (wrapper == null) return const _ParsedBlock(name: '');

    var flag = '';
    final parts = <String>[];
    for (final node in List<dom.Node>.from(wrapper.nodes)) {
      if (node is dom.Element) {
        if (node.localName == 'font' && node.attributes.containsKey('title')) {
          break;
        }
        if (node.localName == 'br') continue;
        final isRedSelf =
            node.localName == 'font' &&
            node.attributes['color'] == 'red';
        final red = isRedSelf
            ? node
            : node.querySelector('font[color="red"]');
        if (red != null && red.text.contains('P')) {
          flag = 'P';
          if (red == node) {
            node.remove();
            continue;
          }
          red.remove();
        }
        final text = _collapse(node.text);
        if (text.isNotEmpty) parts.add(text);
      } else if (node is dom.Text) {
        final text = _collapse(node.text);
        if (text.isNotEmpty) parts.add(text);
      }
    }

    final name = _collapse(parts.join(' ')).replaceAll('&nbsp', '').trim();
    final rawWeeks = _fontTitleText(wrapper, '周次(节次)');
    final periodMatch = RegExp(r'\[([\d,\-\s]+)节\]').firstMatch(rawWeeks);
    final periodText = periodMatch?.group(0) ?? '';
    final weekSections = periodMatch == null
        ? const <int>[]
        : _expandIntRanges(periodMatch.group(1)!);

    var weekPart = rawWeeks.replaceAll(RegExp(r'\[.*?\]'), '');
    var parity = '';
    if (weekPart.contains('双周')) {
      parity = 'even';
    } else if (weekPart.contains('单周')) {
      parity = 'odd';
    }
    final weekExpr = weekPart
        .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
        .replaceAll(RegExp(r'[第周]'), '')
        .trim();
    var weeks = _expandIntRanges(weekExpr);
    if (parity == 'even') {
      weeks = weeks.where((week) => week.isEven).toList(growable: false);
    } else if (parity == 'odd') {
      weeks = weeks.where((week) => week.isOdd).toList(growable: false);
    }

    return _ParsedBlock(
      name: name,
      teacher: _fontTitleText(wrapper, '老师'),
      room: _fontTitleText(wrapper, '教室'),
      flag: flag,
      rawWeeks: rawWeeks,
      rawPeriod: periodText,
      sections: weekSections,
      weeks: weeks,
    );
  }

  static String _fontTitleText(dom.Element root, String title) {
    final element = root.querySelector('font[title="$title"]');
    return element == null ? '' : _collapse(element.text);
  }

  static String _selectedValue(dom.Document document, String name) {
    final select = document.querySelector('select[name="$name"]');
    if (select == null) return '';
    final options = select.querySelectorAll('option');
    for (final option in options) {
      if (option.attributes.containsKey('selected')) {
        return option.attributes['value'] ?? '';
      }
    }
    return options.isEmpty ? '' : (options.first.attributes['value'] ?? '');
  }

  static List<int> _expandIntRanges(String expression) {
    final values = <int>{};
    for (final rawToken in expression.split(RegExp('[,，]'))) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      final range = RegExp(r'^(\d+)\s*[-~]\s*(\d+)$').firstMatch(token);
      if (range != null) {
        final a = int.parse(range.group(1)!);
        final b = int.parse(range.group(2)!);
        final start = a <= b ? a : b;
        final end = a <= b ? b : a;
        for (var value = start; value <= end; value++) {
          values.add(value);
        }
      } else if (RegExp(r'^\d+$').hasMatch(token)) {
        values.add(int.parse(token));
      }
    }
    final result = values.toList()..sort();
    return result;
  }

  static String _collapse(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _ParsedBlock {
  const _ParsedBlock({
    required this.name,
    this.teacher = '',
    this.room = '',
    this.flag = '',
    this.rawWeeks = '',
    this.rawPeriod = '',
    this.sections = const [],
    this.weeks = const [],
  });

  final String name;
  final String teacher;
  final String room;
  final String flag;
  final String rawWeeks;
  final String rawPeriod;
  final List<int> sections;
  final List<int> weeks;
}
