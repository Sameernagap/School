import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Error returned by the school API ({"ok": false, "error": {...}}) or by the network.
class ApiException implements Exception {
  ApiException(this.message, {this.code = 'error', this.status = 0});

  final String message;
  final String code;
  final int status;

  bool get isUnauthorized => status == 401 && code != 'invalid_credentials';

  @override
  String toString() => message;
}

/// Thin client for /api/v1: JSON in and out, bearer token, friendly errors.
class ApiClient {
  ApiClient({required String serverUrl, this.token, this.onUnauthorized})
      : serverUrl = normalizeServer(serverUrl);

  String serverUrl;
  String? token;
  void Function()? onUnauthorized;

  static const Duration _timeout = Duration(seconds: 30);

  /// "192.168.1.5:8069" -> "http://192.168.1.5:8069" ; strips "/api/v1" and trailing slashes.
  static String normalizeServer(String value) {
    var url = value.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - 7);
    }
    return url;
  }

  /// Absolute URL for an API path ("/students" or "/api/v1/students/1/photo").
  String url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/api/')) return '$serverUrl$path';
    final clean = path.startsWith('/') ? path : '/$path';
    return '$serverUrl/api/v1$clean';
  }

  Map<String, String> get authHeaders => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...authHeaders,
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse(url(path));
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    return _send(() => http.get(uri, headers: _jsonHeaders));
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse(url(path));
    return _send(() => http.post(uri, headers: _jsonHeaders, body: jsonEncode(body ?? {})));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The school server is not answering. Check your connection.', code: 'timeout');
    } on SocketException {
      throw ApiException('Cannot reach the school server ($serverUrl). Check the address and Wi-Fi.',
          code: 'network');
    } on http.ClientException catch (e) {
      throw ApiException('Connection problem: ${e.message}', code: 'network');
    } on HandshakeException {
      throw ApiException('Secure connection failed. Check the server address (http/https).', code: 'network');
    }
    dynamic payload;
    try {
      payload = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(
        response.statusCode == 404
            ? 'The school API was not found at $serverUrl. Is the school_api module installed?'
            : 'Unexpected answer from the server (HTTP ${response.statusCode}).',
        code: 'bad_response',
        status: response.statusCode,
      );
    }
    if (payload is Map && payload['ok'] == true) {
      return payload['data'];
    }
    final error = payload is Map && payload['error'] is Map ? payload['error'] as Map : const {};
    final exception = ApiException(
      (error['message'] ?? 'Something went wrong.').toString(),
      code: (error['code'] ?? 'error').toString(),
      status: response.statusCode,
    );
    if (exception.isUnauthorized && onUnauthorized != null) {
      onUnauthorized!();
    }
    throw exception;
  }

  /// Downloads a file (PDF receipt, report card, attachment) to the temp folder.
  Future<File> download(String path, String filename) async {
    final uri = Uri.parse(url(path));
    http.Response response;
    try {
      response = await http.get(uri, headers: authHeaders).timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw ApiException('The download took too long. Try again.', code: 'timeout');
    } on SocketException {
      throw ApiException('Cannot reach the school server.', code: 'network');
    }
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 || type.contains('application/json')) {
      String message = 'Download failed (HTTP ${response.statusCode}).';
      try {
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        if (payload is Map && payload['error'] is Map) {
          message = (payload['error']['message'] ?? message).toString();
        }
      } catch (_) {}
      if (response.statusCode == 401 && onUnauthorized != null) onUnauthorized!();
      throw ApiException(message, status: response.statusCode);
    }
    final dir = await getTemporaryDirectory();
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}
