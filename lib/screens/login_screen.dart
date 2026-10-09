import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _showServer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _server.text = state.serverUrl;
    _error = state.sessionMessage;
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.setServer(_server.text);
      await state.login(_login.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testServer() async {
    final state = context.read<AppState>();
    await state.setServer(_server.text);
    _server.text = state.serverUrl;
    await runAction(context, () async {
      await state.api.get('/ping');
    }, success: 'Connected to ${state.serverUrl}');
  }

  Future<void> _forgot() async {
    final controller = TextEditingController(text: _login.text);
    final login = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Email / login'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Send link')),
        ],
      ),
    );
    if (login == null || login.trim().isEmpty || !mounted) return;
    final state = context.read<AppState>();
    await state.setServer(_server.text);
    await runAction(context, () async {
      final data = await state.api.post('/auth/password/reset', {'login': login.trim()});
      if (mounted) showMessage(context, (data as Map)['message'].toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration:
                          BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(24)),
                      child: const Icon(Icons.school_rounded, size: 42, color: AppColors.night),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Sign in with the login given by your school',
                      textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFC7C3F0))),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.soft(AppColors.rose), borderRadius: BorderRadius.circular(12)),
                              child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            controller: _login,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            decoration: const InputDecoration(labelText: 'Email / login', prefixIcon: Icon(Icons.person_outline)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your login' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _hidePassword,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          if (_showServer) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _server,
                              keyboardType: TextInputType.url,
                              decoration: InputDecoration(
                                labelText: 'School server',
                                hintText: 'http://192.168.1.25:8069',
                                prefixIcon: const Icon(Icons.dns_outlined),
                                suffixIcon: IconButton(
                                  tooltip: 'Test connection',
                                  icon: const Icon(Icons.wifi_tethering),
                                  onPressed: _testServer,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the server address' : null,
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
                              TextButton.icon(
                                onPressed: () => setState(() => _showServer = !_showServer),
                                icon: const Icon(Icons.settings_outlined, size: 18),
                                label: const Text('Server'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(context.watch<AppState>().serverUrl,
                      textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8B87C9), fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
