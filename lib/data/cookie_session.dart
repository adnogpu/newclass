import 'dart:async';

import 'package:http/http.dart' as http;

class CookieSession {
  CookieSession({
    http.Client? client,
    this.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/158.0.0.0 Safari/537.36',
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String userAgent;
  final Duration timeout;
  final Map<String, Map<String, String>> _cookies = {};

  Uri? lastUri;

  void close() => _client.close();

  Map<String, dynamic> exportCookies() => {
    for (final entry in _cookies.entries)
      if (entry.value.isNotEmpty) entry.key: Map<String, String>.from(entry.value),
  };

  void importCookies(Map<String, dynamic> data) {
    _cookies.clear();
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map) {
        final jar = <String, String>{};
        for (final cookie in value.entries) {
          jar['${cookie.key}'] = '${cookie.value}';
        }
        if (jar.isNotEmpty) _cookies[entry.key] = jar;
      }
    }
  }

  void clearCookies() => _cookies.clear();

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    bool followRedirects = true,
  }) => request(
    'GET',
    uri,
    headers: headers,
    followRedirects: followRedirects,
  );

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? form,
    bool followRedirects = true,
  }) => request(
    'POST',
    uri,
    headers: headers,
    form: form,
    followRedirects: followRedirects,
  );

  Future<http.Response> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? form,
    bool followRedirects = true,
    int maxRedirects = 8,
  }) async {
    var currentMethod = method.toUpperCase();
    var currentUri = uri;
    Map<String, String>? currentForm = form;
    final currentHeaders = <String, String>{...?headers};

    for (var redirect = 0; ; redirect++) {
      final request = http.Request(currentMethod, currentUri)
        ..followRedirects = false;
      request.headers.addAll({'User-Agent': userAgent, ...currentHeaders});
      final cookieHeader = _cookieHeader(currentUri);
      if (cookieHeader.isNotEmpty) {
        request.headers['Cookie'] = cookieHeader;
      }
      if (currentForm != null &&
          currentMethod != 'GET' &&
          currentMethod != 'HEAD') {
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'application/x-www-form-urlencoded;charset=UTF-8',
        );
        request.bodyFields = currentForm;
      }

      final streamed = await _client.send(request).timeout(timeout);
      final bytes = await streamed.stream.toBytes().timeout(timeout);
      _captureCookies(
        currentUri,
        streamed.headersSplitValues['set-cookie'] ?? const [],
      );
      lastUri = currentUri;

      final status = streamed.statusCode;
      final location = streamed.headers['location'];
      if (followRedirects &&
          _isRedirect(status) &&
          location != null &&
          location.isNotEmpty &&
          redirect < maxRedirects) {
        currentUri = currentUri.resolve(location);
        if (status == 303 ||
            ((status == 301 || status == 302) &&
                currentMethod != 'GET' &&
                currentMethod != 'HEAD')) {
          currentMethod = 'GET';
          currentForm = null;
          currentHeaders.remove('Content-Type');
        }
        continue;
      }

      final responseHeaders = <String, String>{};
      streamed.headers.forEach((key, value) {
        responseHeaders[key.toLowerCase()] = value;
      });
      return http.Response.bytes(
        bytes,
        status,
        headers: responseHeaders,
        request: request,
      );
    }
  }

  String _cookieHeader(Uri uri) {
    final jar = _cookies[uri.host];
    if (jar == null || jar.isEmpty) return '';
    return jar.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  void _captureCookies(Uri uri, List<String> setCookieHeaders) {
    for (final header in setCookieHeaders) {
      final firstPart = header.split(';').first;
      final separator = firstPart.indexOf('=');
      if (separator <= 0) continue;
      final name = firstPart.substring(0, separator).trim();
      final value = firstPart.substring(separator + 1).trim();
      if (name.isEmpty) continue;
      final jar = _cookies.putIfAbsent(uri.host, () => {});
      final lower = header.toLowerCase();
      if (lower.contains('max-age=0') ||
          lower.contains('expires=thu, 01 jan 1970')) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
      if (jar.isEmpty) _cookies.remove(uri.host);
    }
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;
}
