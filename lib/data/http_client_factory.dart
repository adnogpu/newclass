import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.io) 'http_client_factory_io.dart' as impl;

http.Client createElectricityHttpClient(String host) => impl.createClient(host);
