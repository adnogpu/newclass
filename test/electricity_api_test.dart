import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:newclass/data/electricity_api.dart';

const _base = 'https://example.test/epay/wxpage/wanxiao';

http.Response _json(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MockClient _client() {
  return MockClient((request) async {
    final path = request.url.path;
    final form = request.body.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(request.body);

    if (path.endsWith('/getelesys.json')) {
      return _json({
        'retcode': 0,
        'list': [
          {'sysid': 'S1', 'sysname': '南理工电控'},
        ],
      });
    }
    if (path.endsWith('/getarea.json')) {
      return _json({
        'retcode': 0,
        'list': [
          {'areaid': 'A1', 'areaname': '南京理工'},
        ],
      });
    }
    if (path.endsWith('/getdistrict.json')) {
      return _json({
        'retcode': 0,
        'list': [
          {'districtid': 'D1', 'districtname': '住宿区'},
        ],
      });
    }
    if (path.endsWith('/getbuild.json')) {
      return _json({
        'retcode': 0,
        'list': [
          {'buildid': 'B2', 'buildname': '2号学生公寓'},
          {'buildid': 'B7S', 'buildname': '7号学生公寓南楼'},
          {'buildid': 'B7M', 'buildname': '7号学生公寓中楼'},
          {'buildid': 'B7N', 'buildname': '7号学生公寓北楼'},
        ],
      });
    }
    if (path.endsWith('/getfloor.json')) {
      return _json({
        'retcode': 0,
        'list': [
          if (form['buildid'] == 'B2')
            {'floorid': 'F6', 'floorname': '6楼'}
          else
            {'floorid': 'F2', 'floorname': '2楼'},
        ],
      });
    }
    if (path.endsWith('/getroom.json')) {
      final buildid = form['buildid'];
      if (buildid == 'B2') {
        return _json({
          'retcode': 0,
          'list': [
            {'roomid': 'R2620', 'roomname': '2620室'},
          ],
        });
      }
      if (buildid == 'B7S') {
        return _json({
          'retcode': 0,
          'list': [
            {'roomid': 'R7201S', 'roomname': '7201室'},
            {'roomid': 'R9999', 'roomname': '9999室'},
          ],
        });
      }
      return _json({
        'retcode': 0,
        'list': [
          {'roomid': 'R7201$buildid', 'roomname': '7201室'},
        ],
      });
    }
    if (path.endsWith('/eleresult')) {
      return http.Response(
        '<html><div class="wrap" left-degree="77.52001953125"></div></html>',
        200,
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  test('resolves 2620 through the building/floor fast path', () async {
    final api = ElectricityApi(client: _client(), baseUrl: _base);
    final room = await api.findRoom('2620');
    expect(room.buildName, '2号学生公寓');
    expect(room.floorName, '6楼');
    expect(room.roomName, '2620室');
    expect(room.roomNo, '2620');
  });

  test('reports ambiguous rooms (building 7)', () async {
    final api = ElectricityApi(client: _client(), baseUrl: _base);
    await expectLater(
      api.findRoom('7201'),
      throwsA(
        isA<AmbiguousRoomException>().having(
          (error) => error.candidates.length,
          'candidates',
          3,
        ),
      ),
    );
  });

  test('falls back to a full scan when the fast path misses', () async {
    final api = ElectricityApi(client: _client(), baseUrl: _base);
    final room = await api.findRoom('9999');
    expect(room.buildName, '7号学生公寓南楼');
    expect(room.roomid, 'R9999');
  });

  test('parses the remaining degree attribute', () async {
    final api = ElectricityApi(client: _client(), baseUrl: _base);
    final room = await api.findRoom('2620');
    final balance = await api.queryBalance(room);
    expect(balance.degree, '77.52001953125');
    expect(balance.displayDegree, '77.52');
    expect(balance.room?.roomid, 'R2620');
  });

  test('maps non-zero retcode to a readable error', () async {
    final api = ElectricityApi(
      client: MockClient(
        (_) async => _json({'retcode': '1', 'retmsg': '系统维护中'}),
      ),
      baseUrl: _base,
    );
    await expectLater(
      api.findRoom('2620'),
      throwsA(
        isA<ElectricityApiException>().having(
          (error) => error.message,
          'message',
          '系统维护中',
        ),
      ),
    );
  });

  test('rejects invalid room numbers without a request', () async {
    var called = false;
    final api = ElectricityApi(
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 500);
      }),
      baseUrl: _base,
    );
    await expectLater(
      api.findRoom('12x'),
      throwsA(isA<ElectricityApiException>()),
    );
    expect(called, isFalse);
  });

  test('wraps transport failures as network errors', () async {
    final api = ElectricityApi(
      client: MockClient((_) async => throw Exception('offline')),
      baseUrl: _base,
    );
    await expectLater(
      api.findRoom('2620'),
      throwsA(isA<ElectricityNetworkException>()),
    );
  });
}
