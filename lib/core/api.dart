import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final String code;
  ApiException(this.message, {this.code = 'error'});
  @override
  String toString() => message;
}

/// Thin JSON-RPC client for the `salesman_mobile` Odoo addon.
class ApiClient {
  String baseUrl = '';
  String db = '';
  String? token;

  Future<dynamic> call(String path, [Map<String, dynamic> params = const {}]) async {
    if (baseUrl.isEmpty) throw ApiException('Server URL is not set.');
    final uri = Uri.parse('$baseUrl/salesman/api/$path')
        .replace(queryParameters: db.isNotEmpty ? {'db': db} : null);
    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params}),
          )
          .timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw ApiException('Server timeout. Check your connection.');
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your connection.');
    }
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException('Unexpected server response (HTTP ${res.statusCode}).');
    }
    if (body is Map && body['error'] != null) {
      final e = body['error'];
      throw ApiException((e['data']?['message'] ?? e['message'] ?? 'Server error').toString());
    }
    final result = body['result'];
    if (result is Map && result['ok'] == false) {
      throw ApiException(result['error']?.toString() ?? 'Error', code: result['code']?.toString() ?? 'error');
    }
    return result;
  }
}
