import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:newclass/data/pickup_api.dart';

Map<String, dynamic> _body({
  int code = 200,
  String msg = '请求成功',
  Map<String, dynamic>? data,
}) => {
  'code': code,
  'msg': msg,
  'data': data,
};

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('parses an order that is still in the cabinet', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v3/ele/save/info');
      expect(jsonDecode(request.body), {'sn': '1234567890123456789'});
      expect(request.headers['Authorization'], isNull);
      return http.Response(
        jsonEncode(
          _body(
            data: {
              'cabinet': {
                'name': '二号学生公寓',
                'box': '18',
                'scene': '南京理工大学泰州科技学院',
                'address': '',
              },
              'code_pick': '246810',
              'saved': 0,
            },
          ),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = PickupApi(client: client, baseUrl: 'https://example.test');
    final result = await api.query('1234567890123456789');
    expect(result.inCabinet, isTrue);
    expect(result.pickedUp, isFalse);
    expect(result.cabinet?.name, '二号学生公寓');
    expect(result.cabinet?.box, '18');
    expect(result.pickupCode, '246810');
    expect(result.isElsewhere, isFalse);
  });

  test('marks a picked-up order', () async {
    final client = MockClient((_) async {
      return _jsonResponse(
        _body(
          data: {
            'cabinet': {'name': '二号学生公寓', 'box': '18', 'scene': ''},
            'code_pick': '246810',
            'saved': 1,
          },
        ),
      );
    });
    final api = PickupApi(client: client, baseUrl: 'https://example.test');
    final result = await api.query('1234567890123456789');
    expect(result.pickedUp, isTrue);
    expect(result.inCabinet, isFalse);
  });

  test('reports an order stored in another cabinet', () async {
    final client = MockClient((_) async {
      return _jsonResponse(
        _body(
          data: {
            'save_other': {'cabinet_name': '一号学生公寓'},
            'saved': 0,
          },
        ),
      );
    });
    final api = PickupApi(client: client, baseUrl: 'https://example.test');
    final result = await api.query('1234567890123456789');
    expect(result.isElsewhere, isTrue);
    expect(result.otherCabinet, '一号学生公寓');
  });

  test('surfaces server messages and rejects bad order numbers', () async {
    final client = MockClient((_) async {
      return _jsonResponse(_body(code: 400, msg: '订单不存在'));
    });
    final api = PickupApi(client: client, baseUrl: 'https://example.test');
    await expectLater(
      api.query('1234567890123456789'),
      throwsA(
        isA<PickupException>().having(
          (error) => error.message,
          'message',
          '订单不存在',
        ),
      ),
    );
    await expectLater(
      api.query('abc'),
      throwsA(isA<PickupException>()),
    );
  });

  test('turns transport failures into a friendly error', () async {
    final client = MockClient((_) async => http.Response('bad gateway', 502));
    final api = PickupApi(client: client, baseUrl: 'https://example.test');
    await expectLater(
      api.query('1234567890123456789'),
      throwsA(isA<PickupNetworkException>()),
    );
  });
}
