import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  final _secure = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  bool ready = false;
  Map<String, dynamic>? user;
  Map<String, dynamic> meta = {};
  ThemeMode themeMode = ThemeMode.system;

  bool get loggedIn => api.token != null && user != null;
  String get currency => (meta['currency'] ?? '').toString();
  double get geofenceRadius => (meta['geofence_radius'] ?? 200).toDouble();
  bool get geofenceEnabled => meta['geofence_enabled'] != false;
  double get maxDiscount => (meta['max_discount'] ?? 10).toDouble();
  String get serverUrl => api.baseUrl;
  String get db => api.db;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    api.baseUrl = _prefs.getString('url') ?? '';
    api.db = _prefs.getString('db') ?? '';
    api.token = await _secure.read(key: 'token');
    final u = _prefs.getString('user');
    if (u != null) user = jsonDecode(u);
    themeMode = ThemeMode.values[_prefs.getInt('theme') ?? 0];
    if (loggedIn) {
      try {
        await loadMeta();
      } on ApiException catch (e) {
        if (e.code == 'unauthorized') await logout();
      } catch (_) {/* offline: keep session */}
    }
    ready = true;
    notifyListeners();
  }

  Future<void> loadMeta() async {
    final r = await call('meta');
    meta = Map<String, dynamic>.from(r);
    notifyListeners();
  }

  Future<void> login(String url, String db, String login, String password) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.startsWith('http')) u = 'https://$u';
    api.baseUrl = u;
    api.db = db.trim();
    api.token = null;
    final r = await api.call('login', {'login': login.trim(), 'password': password, 'db': db.trim(), 'device': 'mobile'});
    api.token = r['token'];
    user = Map<String, dynamic>.from(r['user']);
    await _prefs.setString('url', u);
    await _prefs.setString('db', db.trim());
    await _prefs.setString('user', jsonEncode(user));
    await _secure.write(key: 'token', value: api.token);
    await loadMeta();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (api.token != null) await api.call('logout');
    } catch (_) {}
    api.token = null;
    user = null;
    meta = {};
    await _secure.delete(key: 'token');
    await _prefs.remove('user');
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await _prefs.setInt('theme', m.index);
    notifyListeners();
  }

  /// Calls the API; logs out automatically when the token is rejected.
  Future<dynamic> call(String path, [Map<String, dynamic> params = const {}]) async {
    try {
      return await api.call(path, params);
    } on ApiException catch (e) {
      if (e.code == 'unauthorized') await logout();
      rethrow;
    }
  }
}
