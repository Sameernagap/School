import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Session, signed-in user (/me) and the child / role currently shown.
class AppState extends ChangeNotifier {
  AppState() {
    api = ApiClient(serverUrl: defaultServerUrl, onUnauthorized: _sessionExpired);
  }

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'school_token';
  static const _serverKey = 'school_server';
  static const _studentKey = 'school_student';
  static const _modeKey = 'school_mode';

  late ApiClient api;
  AuthStatus status = AuthStatus.loading;
  Map<String, dynamic> me = {};
  int? selectedStudentId;

  /// 'family' (parent / student screens) or 'teacher'
  String mode = 'family';
  String? sessionMessage;

  // ------------------------------------------------------------------
  // Convenience getters on /me
  // ------------------------------------------------------------------
  List<String> get roles => List<String>.from(me['roles'] ?? const []);
  bool get isParent => roles.contains('parent');
  bool get isStudent => roles.contains('student');
  bool get isTeacher => roles.contains('teacher');
  bool get isFamily => isParent || isStudent;
  bool get canSwitchMode => isTeacher && isFamily;
  List<String> get features => List<String>.from(me['features'] ?? const []);
  bool hasFeature(String name) => features.contains(name);
  Map<String, dynamic> get user => Map<String, dynamic>.from(me['user'] ?? const {});
  Map<String, dynamic> get school => Map<String, dynamic>.from(me['school'] ?? const {});
  int get unread => (me['unread_notifications'] ?? 0) as int;

  List<Map<String, dynamic>> get students {
    final list = <Map<String, dynamic>>[];
    for (final child in (me['children'] as List? ?? const [])) {
      list.add(Map<String, dynamic>.from(child as Map));
    }
    if (me['student'] is Map) {
      list.add(Map<String, dynamic>.from(me['student'] as Map));
    }
    return list;
  }

  Map<String, dynamic>? get selectedStudent {
    for (final s in students) {
      if (s['id'] == selectedStudentId) return s;
    }
    return students.isNotEmpty ? students.first : null;
  }

  bool get showTeacher => isTeacher && (!isFamily || mode == 'teacher');

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    api.serverUrl = ApiClient.normalizeServer(prefs.getString(_serverKey) ?? defaultServerUrl);
    selectedStudentId = prefs.getInt(_studentKey);
    mode = prefs.getString(_modeKey) ?? 'family';
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    api.token = token;
    try {
      await refreshMe();
      status = AuthStatus.signedIn;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearSession();
        status = AuthStatus.signedOut;
      } else {
        // offline: keep the session, show the error on the home screen
        sessionMessage = e.message;
        status = me.isEmpty ? AuthStatus.signedOut : AuthStatus.signedIn;
      }
    }
    notifyListeners();
  }

  String get serverUrl => api.serverUrl;

  Future<void> setServer(String url) async {
    api.serverUrl = ApiClient.normalizeServer(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, api.serverUrl);
    notifyListeners();
  }

  Future<void> login(String login, String password) async {
    final data = await api.post('/auth/login', {
      'login': login.trim(),
      'password': password,
      'device_name': _deviceName(),
      'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'),
      'app_version': appVersion,
    }) as Map<String, dynamic>;
    api.token = data['token'] as String;
    await _storage.write(key: _tokenKey, value: api.token);
    me = Map<String, dynamic>.from(data['me'] as Map);
    _fixSelection();
    if (!isFamily && isTeacher) mode = 'teacher';
    sessionMessage = null;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    me = Map<String, dynamic>.from(await api.get('/me') as Map);
    _fixSelection();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {
      // signing out locally is enough when the server cannot be reached
    }
    await _clearSession();
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> selectStudent(int id) async {
    selectedStudentId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_studentKey, id);
    notifyListeners();
  }

  Future<void> setMode(String value) async {
    mode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value);
    notifyListeners();
  }

  /// Register the Firebase token (see README: enabling push notifications).
  Future<void> registerPushToken(String fcmToken) async {
    if (api.token == null) return;
    try {
      await api.post('/auth/device', {
        'fcm_token': fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': appVersion,
      });
    } catch (_) {}
  }

  void setUnread(int value) {
    me['unread_notifications'] = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  void _fixSelection() {
    final ids = students.map((s) => s['id']).toList();
    if (!ids.contains(selectedStudentId)) {
      selectedStudentId = ids.isNotEmpty ? ids.first as int : null;
    }
  }

  void _sessionExpired() {
    if (status != AuthStatus.signedIn) return;
    sessionMessage = 'Your session has expired. Please sign in again.';
    _clearSession();
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    api.token = null;
    me = {};
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  String _deviceName() {
    try {
      if (Platform.isAndroid) return 'Android phone';
      if (Platform.isIOS) return 'iPhone';
    } catch (_) {}
    return 'Mobile app';
  }
}
