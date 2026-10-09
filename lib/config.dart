/// Default server address. Change it on the login screen ("School server"),
/// or at build time: flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8069
///
/// Android emulator -> http://10.0.2.2:8069 (your PC)
/// Real phone       -> http://<your PC's LAN IP>:8069
const String defaultServerUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8069',
);

const String appName = 'School';
const String appVersion = '1.0.0';
