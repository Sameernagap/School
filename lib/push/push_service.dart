import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/inbox_screen.dart';
import '../state/app_state.dart';

/// Phone notifications (Firebase Cloud Messaging).
///
/// * The school server sends a push for every inbox notification (notice, homework, attendance,
///   leave, exam result, fees, library, school bus).
/// * App closed or in the background: Android shows it in the notification panel by itself.
/// * App open: a banner is shown at the bottom and the Inbox badge is refreshed.
/// * Tapping the notification opens the screen it is about.
///
/// Firebase is optional: when the APK was built without google-services.json, push stays off and
/// the Inbox keeps working as before.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  AppState? _state;
  bool _ready = false;
  Map<String, dynamic>? _pendingOpen;

  bool get enabled => _ready;

  /// Call once at start-up, before runApp.
  Future<void> init(AppState state) async {
    _state = state;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _open(message.data));
      messaging.onTokenRefresh.listen((token) => _state?.registerPushToken(token));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _pendingOpen = Map<String, dynamic>.from(initial.data);
      _ready = true;
    } catch (error) {
      debugPrint('Push notifications are off: $error');
    }
  }

  /// Ask permission (Android 13+ / iOS) and send this phone's token to the school server.
  /// Called every time the home screen opens after sign-in.
  Future<void> registerDevice() async {
    if (!_ready || _state == null) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _state!.registerPushToken(token);
    } catch (error) {
      debugPrint('Push registration failed: $error');
    }
  }

  /// Opens the screen of a notification tapped while the app was closed (called by the home screen).
  void openPending() {
    final data = _pendingOpen;
    if (data == null) return;
    _pendingOpen = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(data));
  }

  // ------------------------------------------------------------------
  void _onForegroundMessage(RemoteMessage message) {
    final state = _state;
    if (state != null) {
      state.setUnread(state.unread + 1);
      state.refreshMe().catchError((_) {});
    }
    final title = message.notification?.title ?? 'New notification';
    final body = message.notification?.body ?? '';
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (body.isNotEmpty) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      action: SnackBarAction(label: 'VIEW', onPressed: () => _open(message.data)),
    ));
  }

  Future<void> _open(Map<String, dynamic> data) async {
    final state = _state;
    final context = navigatorKey.currentContext;
    if (state == null || state.status != AuthStatus.signedIn) {
      _pendingOpen = data; // opened again once signed in
      return;
    }
    if (context == null) return;
    final n = <String, dynamic>{
      'category': data['category'] ?? 'general',
      'student_id': int.tryParse('${data['student_id'] ?? ''}'),
      'res_id': int.tryParse('${data['res_id'] ?? ''}'),
    };
    final id = int.tryParse('${data['notification_id'] ?? ''}');
    if (id != null) {
      try {
        await state.api.post('/notifications/read', {'ids': [id]});
        state.setUnread(state.unread > 0 ? state.unread - 1 : 0);
      } catch (_) {}
    }
    if (!context.mounted) return;
    if (!openNotificationTarget(context, n)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
    }
  }
}
