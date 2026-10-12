import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'push/push_service.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await PushService.instance.init(state);
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const SchoolApp(),
    ),
  );
  state.init();
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: PushService.instance.navigatorKey,
      scaffoldMessengerKey: PushService.instance.messengerKey,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, AuthStatus>((s) => s.status);
    switch (status) {
      case AuthStatus.loading:
        return const _Splash();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const HomeShell();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.school_rounded, size: 46, color: AppColors.night),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
