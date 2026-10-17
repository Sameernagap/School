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
  static const _levelKey = 'school_login_level';
  static const _levelChosenKey = 'school_login_level_chosen';
  static const _rememberKey = 'school_remember';
  static const _savedLoginKey = 'school_saved_login';

  late ApiClient api;
  AuthStatus status = AuthStatus.loading;
  Map<String, dynamic> me = {};
  int? selectedStudentId;

  /// 'family' (parent / student screens) or 'teacher'
  String mode = 'family';
  String? sessionMessage;

  /// Sign-in design to show: 'preprimary', 'primary' or 'secondary' (the section of the last user).
  String? loginLevel;

  /// True when the user picked the sign-in design on this phone (then sign-in does not change it).
  bool loginLevelChosen = false;
  bool rememberMe = true;
  String savedLogin = '';

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
    loginLevel = prefs.getString(_levelKey);
    loginLevelChosen = prefs.getBool(_levelChosenKey) ?? false;
    rememberMe = prefs.getBool(_rememberKey) ?? true;
    savedLogin = prefs.getString(_savedLoginKey) ?? '';
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

  /// Sign in. [role] ('parent', 'student' or 'teacher') is the role chosen on the sign-in screen:
  /// the account must have it, and it decides which home screen opens. Without [remember] the
  /// session ends when the app is closed.
  Future<void> login(String login, String password, {String? role, bool remember = true}) async {
    final data = await api.post('/auth/login', {
      'login': login.trim(),
      'password': password,
      'device_name': _deviceName(),
      'platform': Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'),
      'app_version': appVersion,
    }) as Map<String, dynamic>;
    api.token = data['token'] as String;
    me = Map<String, dynamic>.from(data['me'] as Map);
    if (role != null && !roles.contains(role)) {
      final names = {'parent': 'Parent', 'student': 'Student', 'teacher': 'Teacher'};
      final available = roles.where(names.containsKey).map((r) => names[r]).join(' or ');
      try {
        await api.post('/auth/logout');
      } catch (_) {}
      api.token = null;
      me = {};
      throw ApiException(available.isEmpty
          ? 'This login has no access to the app. Ask the school office.'
          : 'This is not a ${names[role]} login. Choose $available above.');
    }
    final prefs = await SharedPreferences.getInstance();
    rememberMe = remember;
    await prefs.setBool(_rememberKey, remember);
    if (remember) {
      savedLogin = login.trim();
      await prefs.setString(_savedLoginKey, savedLogin);
      await _storage.write(key: _tokenKey, value: api.token);
    } else {
      savedLogin = '';
      await prefs.remove(_savedLoginKey);
      try {
        await _storage.delete(key: _tokenKey);
      } catch (_) {}
    }
    _fixSelection();
    if (role == 'teacher' || (!isFamily && isTeacher)) {
      mode = 'teacher';
    } else if (role != null) {
      mode = 'family';
    }
    await prefs.setString(_modeKey, mode);
    await _rememberLevel();
    sessionMessage = null;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  /// Section of the signed-in user, so the next sign-in screen uses the same design.
  Future<void> _rememberLevel() async {
    if (loginLevelChosen) return; // the user picked a design on this phone
    String? level;
    if (showTeacher) {
      final teacher = me['teacher'] is Map ? me['teacher'] as Map : const {};
      final levels = (teacher['levels'] as List? ?? const []).cast<String>();
      if (levels.isNotEmpty) level = levels.contains('primary') ? 'primary' : levels.first;
    } else {
      level = selectedStudent?['level'] as String?;
    }
    if (level == null) return;
    loginLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_levelKey, level);
  }

  /// Sign-in design picked on the sign-in screen; null goes back to automatic.
  Future<void> setLoginLevel(String? level) async {
    final prefs = await SharedPreferences.getInstance();
    loginLevel = level;
    loginLevelChosen = level != null;
    if (level == null) {
      await prefs.remove(_levelKey);
    } else {
      await prefs.setString(_levelKey, level);
    }
    await prefs.setBool(_levelChosenKey, loginLevelChosen);
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
    await _rememberLevel();
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
