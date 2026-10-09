# School App (Flutter)

One app for **parents, students and teachers**, connected to the Odoo 19 school system
through the `school_api` module (`/api/v1`).

| Who | What they get |
|---|---|
| Parent | Child switcher, attendance calendar, leave requests, timetable, homework, fees with **Pay now** and receipts, exam date sheet, results and report card PDF, school bus, library, notices, inbox |
| Student | The same screens for themselves |
| Teacher | Today's numbers, take attendance (P / A / L with one tap), approve leave, give homework and tick submissions, enter marks, send notices, timetable, class lists |
| Teacher who is also a parent | A **Family / Teacher** switch on the home screen |

---

## 1. Create the project (once)

Needs Flutter 3.22 or newer (`flutter --version`).

```bash
unzip school_app.zip && cd school_app
flutter create --org com.bingoforge --project-name school_app --platforms android,ios .
flutter pub get
```

`flutter create .` only adds the missing platform folders (android/, ios/); it keeps the
files from this zip (lib/, pubspec.yaml, android/app/src/debug/...).

## 2. Run against Odoo on your PC (http, localhost)

1. **Odoo** (`odoo.conf`): `http_interface = 0.0.0.0`, and one database for the API:
   `db_name = school_db` + `dbfilter = ^school_db$`. Install the `school_api` module. Restart Odoo.
2. **Check** from the phone's browser: `http://<PC-IP>:8069/api/v1/ping` must answer `{"ok": true ...}`.
   (`hostname -I` shows the PC's IP; open the port with `sudo ufw allow 8069/tcp` if ufw is on.)
3. **Run the app**:

```bash
# Android emulator (10.0.2.2 = your PC)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8069

# Real phone on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8069
```

You can also change the address in the app: login screen › **Server** › type the address ›
tap the antenna icon to test the connection.

**Plain http is allowed in debug builds only:**
* Android: already done by `android/app/src/debug/AndroidManifest.xml` and
  `android/app/src/debug/res/xml/network_security_config.xml` (included).
* iOS simulator / iPhone: add to `ios/Runner/Info.plist` inside the main `<dict>` (remove before App Store release):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Pay now / PDFs on the phone:** in Odoo set the system parameter `web.base.url` to
`http://<PC-IP>:8069` and add `web.base.url.freeze` = `True`, otherwise the payment link points to
`localhost`, which the phone cannot open.

### Demo logins (database with demo data)

* Parent: give **Suresh Patil** app access in Odoo (Parents › Suresh Patil › *Grant App Access*), then set a
  password on his user (Settings › Users). Children: Aarav and Diya.
* Teacher: create a user for **Anita Sharma** with the *School / Teacher* role and link it on the employee
  (Employees › Anita Sharma › *Related User*). She is class teacher of Class 1-A.

## 3. Project structure

```
lib/
  main.dart                 app start, routes signed-in / signed-out
  config.dart               default server address (API_BASE_URL)
  theme.dart                colours (same as the Odoo back office), status colours
  api/api_client.dart       /api/v1 client: bearer token, JSON, friendly errors, file downloads
  state/app_state.dart      session, /me, selected child, family/teacher mode (Provider)
  utils/format.dart         dates, money formatting, initials
  widgets/common.dart       cards, chips, loaders, error/empty views, open PDF / pay link
  screens/
    login_screen.dart       sign in, forgot password, server address
    home_shell.dart         bottom navigation: Home · Notices · Inbox · Profile
    family_home.dart        parent / student dashboard
    teacher_home.dart       teacher dashboard
    notices_screen.dart     notices + detail with attachments
    inbox_screen.dart       notification inbox (opens the related screen)
    profile_screen.dart     account, change password, sign out
    student/                attendance, leaves, timetable, homework, fees, exams & results,
                            transport, library, student profile
    teacher/                classes, take attendance, leave approvals, homework, marks entry, send notice
```

The token is kept in the phone's secure storage (Keychain / Android Keystore). When the server
answers 401 (expired or signed out by the admin), the app returns to the login screen.

## 4. Push notifications (Firebase) – when you are ready

The app already shows every notification in the **Inbox**. To also get them as phone
notifications:

1. Create a Firebase project, add an Android app (`com.bingoforge.school_app`) and an iOS app.
2. `dart pub global activate flutterfire_cli` then `flutterfire configure` in this folder
   (creates `lib/firebase_options.dart` and the platform files).
3. `flutter pub add firebase_core firebase_messaging`
4. In `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const SchoolApp()));
  await state.init();
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final token = await messaging.getToken();
  if (token != null) await state.registerPushToken(token);
  messaging.onTokenRefresh.listen(state.registerPushToken);
}
```

   Also call `registerPushToken` right after a successful login (e.g. at the end of `AppState.login`).
5. In Odoo: Settings › School › Mobile App › enable *Push notifications*, paste the Firebase
   project ID and the service-account JSON key, then *Send me a test notification*.

Tapping a notification: the message `data` has `category`, `student_id` and `res_id`; pass it to
`openNotificationTarget(context, data)` from `inbox_screen.dart` to open the right screen.

## 5. Release builds

* Use the school's HTTPS address: `flutter build apk --release --dart-define=API_BASE_URL=https://school.example.com`
  (or `flutter build appbundle` for the Play Store, `flutter build ipa` for the App Store).
* Release builds refuse plain http (the debug-only Android files are not included in release).
* Set the app name and icon (`android/app/src/main/AndroidManifest.xml` `android:label`,
  `ios/Runner/Info.plist` `CFBundleDisplayName`; icons with `flutter_launcher_icons`).

## 6. Tests

```bash
flutter test        # address handling and formatting helpers
flutter analyze
```
