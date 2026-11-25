import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/models/schedule_data.dart';
import '../core/schedule/schedule_parser.dart';
import 'cas_crypto.dart';
import 'cookie_session.dart';

class ScheduleException implements Exception {
  const ScheduleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleNetworkException extends ScheduleException {
  const ScheduleNetworkException(super.message);
}

class ScheduleSessionExpiredException extends ScheduleException {
  const ScheduleSessionExpiredException([super.message = '登录状态已失效']);
}

class LoginException extends ScheduleException {
  const LoginException(super.message);
}

class CaptchaRejectedException extends LoginException {
  const CaptchaRejectedException() : super('验证码错误');
}

class CaptchaChallenge {
  const CaptchaChallenge({required this.uid, required this.imageBytes});

  final String uid;
  final Uint8List imageBytes;
}

class ScheduleApi {
  ScheduleApi({CookieSession? session}) : session = session ?? CookieSession();

  static const casBase = 'https://cas.nustti.edu.cn';
  static const jwBase = 'https://jwgl.nustti.edu.cn';
  static const casService = '$jwBase/sso.jsp';

  final CookieSession session;

  String _ticket = '';

  bool get hasCookies => session.exportCookies().isNotEmpty;

  void close() => session.close();

  String exportCookiesJson() => jsonEncode(session.exportCookies());

  void importCookiesJson(String raw) {
    if (raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        session.importCookies(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<CaptchaChallenge> fetchCaptcha() async {
    try {
      final uri = Uri.parse('$casBase/lyuapServer/kaptcha').replace(
        queryParameters: {
          'uid': '',
          '_t': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final response = await session.get(
        uri,
        headers: {'Referer': '$casBase/lyuapServer/login'},
      );
      if (response.statusCode >= 400) {
        throw const ScheduleException('验证码加载失败');
      }
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map) {
        throw const ScheduleException('验证码返回异常');
      }
      final uid = '${decoded['uid'] ?? ''}';
      final content = '${decoded['content'] ?? ''}';
      if (uid.isEmpty || content.isEmpty) {
        throw const ScheduleException('验证码返回异常');
      }
      final comma = content.indexOf(',');
      final base64Part = comma >= 0 ? content.substring(comma + 1) : content;
      return CaptchaChallenge(
        uid: uid,
        imageBytes: base64Decode(base64Part),
      );
    } on ScheduleException {
      rethrow;
    } on TimeoutException {
      throw const ScheduleNetworkException('连接超时，请稍后重试');
    } catch (_) {
      throw const ScheduleNetworkException('网络连接失败，请稍后重试');
    }
  }

  Future<void> login({
    required String username,
    required String password,
    required String captchaUid,
    required String answer,
  }) async {
    try {
      final serverMs = await _serverMilliseconds();
      final token = CasCrypto.rawRsaHex('lyasp$serverMs');
      final referer =
          '$casBase/lyuapServer/login?service=${Uri.encodeComponent(casService)}';
      final response = await session.post(
        Uri.parse('$casBase/lyuapServer/v1/tickets'),
        followRedirects: false,
        headers: {
          'Origin': casBase,
          'Referer': referer,
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
          'loginUserToken': token,
        },
        form: {
          'username': username,
          'password': CasCrypto.rawRsaHex(password),
          'service': casService,
          'loginType': '',
          'id': captchaUid,
          'code': answer,
        },
      );

      final decoded = _decodeJson(response);
      final ticket = '${decoded['ticket'] ?? ''}';
      final tgt = '${decoded['tgt'] ?? ''}';
      if (ticket.isNotEmpty) {
        _ticket = ticket;
      } else if (tgt.isNotEmpty) {
        await _exchangeTicket(tgt, referer);
      } else {
        final data = decoded['data'];
        final code = data is Map ? '${data['code'] ?? ''}' : '';
        if (code == 'CODEFALSE') {
          throw const CaptchaRejectedException();
        }
        if (code == 'PASSERROR') {
          throw const LoginException('密码错误，请检查后重试');
        }
        final meta = decoded['meta'];
        final message = meta is Map
            ? '${meta['message'] ?? ''}'
            : '';
        throw LoginException(
          message.isEmpty ? '登录失败，请稍后重试' : message,
        );
      }

      await _ssoToJw();
    } on ScheduleException {
      rethrow;
    } on TimeoutException {
      throw const ScheduleNetworkException('连接超时，请稍后重试');
    } catch (_) {
      throw const ScheduleNetworkException('网络连接失败，请稍后重试');
    }
  }

  Future<ScheduleData> fetchSchedule() async {
    try {
      final response = await session.get(
        Uri.parse('$jwBase/jsxsd/xskb/xskb_list.do'),
      );
      if (response.statusCode >= 400) {
        throw const ScheduleException('课表请求失败');
      }
      final html = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );
      if (!html.contains('kbtable')) {
        if (html.contains('lyuapServer') ||
            html.contains('login') ||
            (session.lastUri?.toString().contains('login') ?? false)) {
          throw const ScheduleSessionExpiredException();
        }
        throw const ScheduleException('课表页面异常，请稍后重试');
      }
      return ScheduleParser.parse(html);
    } on ScheduleException {
      rethrow;
    } on TimeoutException {
      throw const ScheduleNetworkException('连接超时，请稍后重试');
    } on ScheduleParseException catch (error) {
      throw ScheduleException(error.message);
    } catch (_) {
      throw const ScheduleNetworkException('网络连接失败，请稍后重试');
    }
  }

  Future<void> _exchangeTicket(String tgt, String referer) async {
    final response = await session.post(
      Uri.parse('$casBase/lyuapServer/v1/tickets/${Uri.encodeComponent(tgt)}'),
      followRedirects: false,
      headers: {'Referer': referer},
      form: {'service': casService},
    );
    final location = response.headers['location'] ?? '';
    final match =
        RegExp(r'ST-[A-Za-z0-9._-]+').firstMatch(location) ??
        RegExp(r'ST-[A-Za-z0-9._-]+').firstMatch(
          utf8.decode(response.bodyBytes, allowMalformed: true),
        );
    if (match == null) {
      throw const LoginException('换取登录票据失败');
    }
    _ticket = match.group(0)!;
  }

  Future<void> _ssoToJw() async {
    final response = await session.get(
      Uri.parse('$jwBase/sso.jsp?ticket=${Uri.encodeComponent(_ticket)}'),
    );
    final finalUri = session.lastUri?.toString() ?? '';
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (!finalUri.contains('xsMain') &&
        !finalUri.contains('jsxsd') &&
        !body.contains('xsMain') &&
        !body.contains('jsxsd')) {
      throw const LoginException('教务系统登录失败');
    }
  }

  Future<int> _serverMilliseconds() async {
    try {
      final response = await session.get(Uri.parse('$casBase/'));
      final date = parseHttpDate(response.headers['date']);
      if (date != null) return date.millisecondsSinceEpoch;
    } catch (_) {}
    return DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const LoginException('登录服务返回异常');
  }
}
