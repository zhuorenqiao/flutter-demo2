import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';

/// 默认后端地址，可用 `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9090` 覆盖
/// （Android 模拟器访问宿主机要用 10.0.2.2）。
const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:9090',
);

class SessionUser {
  const SessionUser(this.id, this.username, this.nickname);

  final int id;
  final String username;
  final String nickname;

  factory SessionUser.fromJson(Map<String, dynamic> json) =>
      SessionUser(
        (json['id'] as num).toInt(),
        json['username'] as String,
        json['nickname'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'nickname': nickname,
  };
}

/// 保存 JWT 与服务器地址，负责注册 / 登录 / 退出。
class AuthSession extends ChangeNotifier {
  AuthSession._(this._prefs, this._baseUrl, this._token, this._user);

  static const _kBaseUrl = 'api.baseUrl';
  static const _kToken = 'auth.token';
  static const _kUser = 'auth.user';

  static Future<AuthSession> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_kUser);
    return AuthSession._(
      prefs,
      prefs.getString(_kBaseUrl) ?? defaultApiBaseUrl,
      prefs.getString(_kToken),
      rawUser == null
          ? null
          : SessionUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>),
    );
  }

  final SharedPreferences _prefs;

  String _baseUrl;
  String? _token;
  SessionUser? _user;
  ApiClient? _api;

  String get baseUrl => _baseUrl;
  SessionUser? get user => _user;
  bool get isSignedIn => _token != null;
  String get displayName => _user?.nickname.isNotEmpty == true ? _user!.nickname : (_user?.username ?? '');

  ApiClient get api => _api ??= ApiClient(
    baseUrl: _baseUrl,
    token: () => _token,
    onUnauthorized: _expireToken,
  );

  Future<void> setBaseUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _baseUrl = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    _api?.updateBaseUrl(_baseUrl);
    await _prefs.setString(_kBaseUrl, _baseUrl);
    notifyListeners();
  }

  Future<void> login(String username, String password) =>
      _authenticate('/api/auth/login', {'username': username.trim(), 'password': password});

  Future<void> register(String username, String password, String nickname) => _authenticate(
    '/api/auth/register',
    {
      'username': username.trim(),
      'password': password,
      'nickname': nickname.trim(),
    },
  );

  Future<void> signOut() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> _authenticate(String path, Map<String, Object?> body) async {
    final payload = await api.post(path, body) as Map;
    await _applyToken(payload.cast<String, dynamic>());
  }

  Future<void> _applyToken(Map<String, dynamic> payload) async {
    _token = payload['token'] as String;
    _user = SessionUser.fromJson(payload['user'] as Map<String, dynamic>);
    await _prefs.setString(_kToken, _token!);
    await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  /// 后端返回 401（token 过期或被撤销）时清掉本地会话，UI 回到登录页。
  void _expireToken() {
    if (_token == null) return;
    _token = null;
    _user = null;
    unawaited(_prefs.remove(_kToken));
    unawaited(_prefs.remove(_kUser));
    notifyListeners();
  }
}
