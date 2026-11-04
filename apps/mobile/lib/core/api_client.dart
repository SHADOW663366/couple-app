import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  void setToken(String? token) => _token = token;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final res = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) async {
    final res = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(auth: auth),
    );
    return _decode(res);
  }

  Map<String, String> _headers({required bool auth}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // localtunnel 免费页拦截绕过
      'bypass-tunnel-reminder': '1',
      'User-Agent': 'CoupleApp/1.0',
    };
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response res) {
    final map = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map;
    }
    final message = map['message'];
    final text = message is List
        ? message.join(', ')
        : (message?.toString() ?? '请求失败 (${res.statusCode})');
    throw ApiException(text, statusCode: res.statusCode);
  }
}
