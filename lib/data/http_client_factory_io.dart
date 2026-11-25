import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createClient(String requestHost) {
  final inner = HttpClient();
  inner.badCertificateCallback = (certificate, host, port) =>
      host == requestHost;
  inner.connectionTimeout = const Duration(seconds: 20);
  return IOClient(inner);
}
