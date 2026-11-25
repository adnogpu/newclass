import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/electricity_balance.dart';
import '../core/models/room_ref.dart';
import 'http_client_factory.dart';

class ElectricityException implements Exception {
  const ElectricityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ElectricityApiException extends ElectricityException {
  const ElectricityApiException(super.message);
}

class ElectricityNetworkException extends ElectricityException {
  const ElectricityNetworkException(super.message);
}

class AmbiguousRoomException extends ElectricityException {
  const AmbiguousRoomException(this.roomNo, this.candidates)
    : super('房间 $roomNo 在多个楼栋中存在');

  final String roomNo;
  final List<RoomRef> candidates;
}

class ElectricityApi {
  ElectricityApi({
    http.Client? client,
    String? baseUrl,
    Duration? timeout,
  }) : _client = client ?? createElectricityHttpClient(_host),
       _ownsClient = client == null,
       baseUrl = baseUrl ?? ElectricityApi.defaultBaseUrl,
       timeout = timeout ?? const Duration(seconds: 30);

  static const defaultBaseUrl =
      'https://ykt.tzu.edu.cn:5005/epay/wxpage/wanxiao';
  static const _host = 'ykt.tzu.edu.cn';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120 Safari/537.36';

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<RoomRef> findRoom(String roomNo, {String? buildFilter}) async {
    final normalized = roomNo.trim();
    if (!RegExp(r'^\d{3,6}$').hasMatch(normalized)) {
      throw const ElectricityApiException('房间号应为 3-6 位数字');
    }

    final scope = await _resolveScope();
    var builds = await this.builds(
      sysid: scope.sysid,
      areaid: scope.areaid,
      districtid: scope.districtid,
    );
    if (builds.isEmpty) {
      throw const ElectricityApiException('没有可用的楼栋');
    }

    if (buildFilter != null && buildFilter.trim().isNotEmpty) {
      final filter = buildFilter.trim();
      builds = builds
          .where(
            (build) =>
                _idOf(build) == filter ||
                _nameOf(build).contains(filter),
          )
          .toList(growable: false);
      if (builds.isEmpty) {
        throw const ElectricityApiException('找不到楼栋');
      }
    }

    if (normalized.length >= 4) {
      final buildingNo = normalized[0];
      final floorNo = normalized[1];
      final candidates = builds
          .where((build) => _nameOf(build).startsWith('$buildingNo号'))
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        final found = <RoomRef>[];
        for (final build in candidates) {
          final buildFloors = await floors(
            sysid: scope.sysid,
            areaid: scope.areaid,
            districtid: scope.districtid,
            buildid: _idOf(build),
          );
          for (final floor in buildFloors) {
            if (_nameOf(floor) != '$floorNo楼') continue;
            found.addAll(
              await _collect(
                scope: scope,
                build: build,
                floor: floor,
                roomNo: normalized,
              ),
            );
          }
        }
        if (found.length == 1) return found.first;
        if (found.length > 1) {
          throw AmbiguousRoomException(normalized, found);
        }
      }
    }

    final found = <RoomRef>[];
    for (final build in builds) {
      final buildFloors = await floors(
        sysid: scope.sysid,
        areaid: scope.areaid,
        districtid: scope.districtid,
        buildid: _idOf(build),
      );
      for (final floor in buildFloors) {
        found.addAll(
          await _collect(
            scope: scope,
            build: build,
            floor: floor,
            roomNo: normalized,
          ),
        );
      }
    }
    if (found.length == 1) return found.first;
    if (found.length > 1) {
      throw AmbiguousRoomException(normalized, found);
    }
    throw ElectricityApiException('未找到房间 $normalized');
  }

  Future<ElectricityBalance> queryBalance(RoomRef room) async {
    final uri = Uri.parse('$baseUrl/eleresult').replace(
      queryParameters: {
        'sysid': room.sysid,
        'roomid': room.roomid,
        'areaid': room.areaid,
        'buildid': room.buildid,
      },
    );
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(timeout);
      if (response.statusCode >= 400) {
        throw const ElectricityApiException('服务暂时不可用');
      }
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final match = RegExp(r'left-degree="([^"]+)"').firstMatch(html);
      if (match == null) {
        throw const ElectricityApiException('页面中未找到剩余电量');
      }
      return ElectricityBalance(
        degree: match.group(1)!,
        fetchedAt: DateTime.now(),
        room: room,
      );
    } on ElectricityException {
      rethrow;
    } on TimeoutException {
      throw const ElectricityNetworkException('连接超时，请稍后重试');
    } catch (_) {
      throw const ElectricityNetworkException('网络连接失败，请稍后重试');
    }
  }

  Future<List<Map<String, dynamic>>> systems() => _post(
    '/getelesys.json',
    jsonBody: true,
  );

  Future<List<Map<String, dynamic>>> areas(String sysid) =>
      _post('/getarea.json', form: {'sysid': sysid});

  Future<List<Map<String, dynamic>>> districts(
    String sysid,
    String areaid,
  ) => _post('/getdistrict.json', form: {
    'sysid': sysid,
    'areaid': areaid,
  });

  Future<List<Map<String, dynamic>>> builds({
    required String sysid,
    required String areaid,
    required String districtid,
  }) => _post('/getbuild.json', form: {
    'sysid': sysid,
    'areaid': areaid,
    'districtid': districtid,
  });

  Future<List<Map<String, dynamic>>> floors({
    required String sysid,
    required String areaid,
    required String districtid,
    required String buildid,
  }) => _post('/getfloor.json', form: {
    'sysid': sysid,
    'areaid': areaid,
    'districtid': districtid,
    'buildid': buildid,
  });

  Future<List<Map<String, dynamic>>> rooms({
    required String sysid,
    required String areaid,
    required String districtid,
    required String buildid,
    required String floorid,
  }) => _post('/getroom.json', form: {
    'sysid': sysid,
    'areaid': areaid,
    'districtid': districtid,
    'buildid': buildid,
    'floorid': floorid,
  });

  Future<_Scope> _resolveScope() async {
    final systems = await this.systems();
    if (systems.isEmpty) {
      throw const ElectricityApiException('没有可用的电控校区');
    }
    final system = _pick(systems, '南理工电控') ?? systems.first;
    final sysid = _idOf(system);

    final areas = await this.areas(sysid);
    if (areas.isEmpty) {
      throw const ElectricityApiException('没有可用的缴费校区');
    }
    final area = _pick(areas, '南京理工') ?? areas.first;
    final areaid = _idOf(area);

    final districts = await this.districts(sysid, areaid);
    if (districts.isEmpty) {
      throw const ElectricityApiException('没有可用的缴费区域');
    }
    final district = _pick(districts, '住宿区') ?? districts.first;
    return _Scope(
      sysid: sysid,
      areaid: areaid,
      districtid: _idOf(district),
    );
  }

  Future<List<RoomRef>> _collect({
    required _Scope scope,
    required Map<String, dynamic> build,
    required Map<String, dynamic> floor,
    required String roomNo,
  }) async {
    final buildid = _idOf(build);
    final floorid = _idOf(floor);
    final items = await rooms(
      sysid: scope.sysid,
      areaid: scope.areaid,
      districtid: scope.districtid,
      buildid: buildid,
      floorid: floorid,
    );
    final out = <RoomRef>[];
    for (final item in items) {
      if (!_matchRoom(item, roomNo)) continue;
      out.add(
        RoomRef(
          roomNo: roomNo,
          sysid: scope.sysid,
          areaid: scope.areaid,
          districtid: scope.districtid,
          buildid: buildid,
          floorid: floorid,
          roomid: _idOf(item),
          roomName: _nameOf(item),
          buildName: _nameOf(build),
          floorName: _nameOf(floor),
        ),
      );
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _post(
    String path, {
    Map<String, String>? form,
    bool jsonBody = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'User-Agent': _userAgent};
    try {
      http.Response response;
      if (jsonBody) {
        headers['Content-Type'] = 'application/json; charset=utf-8';
        response = await _client
            .post(uri, headers: headers, body: '{}')
            .timeout(timeout);
      } else {
        response = await _client
            .post(uri, headers: headers, body: form ?? const {})
            .timeout(timeout);
      }
      if (response.statusCode >= 400) {
        throw const ElectricityApiException('服务暂时不可用');
      }
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map) {
        throw const ElectricityApiException('接口返回异常');
      }
      final json = Map<String, dynamic>.from(decoded);
      if ('${json['retcode']}' != '0') {
        final message = '${json['retmsg'] ?? json['retcode'] ?? '查询失败'}';
        throw ElectricityApiException(message);
      }
      final list = json['list'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } on ElectricityException {
      rethrow;
    } on TimeoutException {
      throw const ElectricityNetworkException('连接超时，请稍后重试');
    } catch (_) {
      throw const ElectricityNetworkException('网络连接失败，请稍后重试');
    }
  }

  static String _nameOf(Map<String, dynamic> item) {
    for (final entry in item.entries) {
      if (entry.key.toLowerCase().contains('name')) {
        return '${entry.value}';
      }
    }
    return '';
  }

  static String _idOf(Map<String, dynamic> item) {
    for (final entry in item.entries) {
      if (entry.key.toLowerCase().endsWith('id')) {
        return '${entry.value}';
      }
    }
    throw const ElectricityApiException('接口数据缺少 id');
  }

  static Map<String, dynamic>? _pick(
    List<Map<String, dynamic>> items,
    String keyword,
  ) {
    for (final item in items) {
      if (_nameOf(item).contains(keyword)) return item;
    }
    return null;
  }

  static bool _matchRoom(Map<String, dynamic> item, String roomNo) {
    final name = _nameOf(item).trim();
    if (name == roomNo) return true;
    return name.replaceAll(RegExp(r'\D'), '') == roomNo;
  }
}

class _Scope {
  const _Scope({
    required this.sysid,
    required this.areaid,
    required this.districtid,
  });

  final String sysid;
  final String areaid;
  final String districtid;
}
