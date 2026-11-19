import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static String base = '', db = '';
  static String? _cookie;
  static int _id = 0;
  static Map<String, String> get headers => {if (_cookie != null) 'Cookie': _cookie!};

  static Future<dynamic> _rpc(String path, Map params) async {
    final r = await http.post(Uri.parse('$base$path'),
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'id': ++_id, 'params': params}));
    final c = r.headers['set-cookie'];
    if (c != null && c.contains('session_id')) _cookie = c.split(';').first;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j['error'] != null) throw Exception(j['error']['data']?['message'] ?? 'Server error');
    return j['result'];
  }

  static Future<void> login(String url, String database, String user, String pass) async {
    base = url.replaceAll(RegExp(r'/+$'), ''); db = database;
    final r = await _rpc('/web/session/authenticate', {'db': db, 'login': user, 'password': pass});
    if (r == null || r['uid'] == null || r['uid'] == false) throw Exception('Invalid login');
  }

  static Future<Map> dashboard() async => await _rpc('/salesman/api/dashboard', {});
  static Future<List> customers() async => await _rpc('/salesman/api/customers', {});
  static Future<List> stock() async => await _rpc('/salesman/api/stock', {});
  static Future<List> orders() async => await _rpc('/salesman/api/orders', {});
  static Future<List> invoices(String? s) async => await _rpc('/salesman/api/invoices', {'payment_state': s ?? false});
  static Future<Map> payment(int id, double amt) async => await _rpc('/salesman/api/payment', {'invoice_id': id, 'amount': amt});
  static Future<Map> order(int pid, double lat, double lng, List lines) async =>
      await _rpc('/salesman/api/order', {'partner_id': pid, 'lat': lat, 'lng': lng, 'lines': lines});
  static Future<Map> createCustomer(Map d) async => await _rpc('/salesman/api/customer/create', d);
  static Future<List> orderLines(int id) async => await _rpc('/salesman/api/order/lines', {'order_id': id});
  static Future<Map> returnProducts(int id, List l) async => await _rpc('/salesman/api/return', {'order_id': id, 'lines': l});
  static Future<List> catalog() async => await _rpc('/salesman/api/catalog', {});
  static Future<Map> requestStock(List l) async => await _rpc('/salesman/api/stock/request', {'lines': l});
}
