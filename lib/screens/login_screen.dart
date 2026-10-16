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
  Map<String, dynamic>? _school;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _server.text = state.serverUrl;
    _error = state.sessionMessage;
    _loadSchool();
  }

  /// School name, logo and sign-in photo from the server (shown above the form).
  Future<void> _loadSchool() async {
    try {
      final data = await context.read<AppState>().api.get('/ping');
      if (data is Map && data['school'] is Map && mounted) {
        setState(() => _school = Map<String, dynamic>.from(data['school'] as Map));
      }
    } catch (_) {
      // server not reachable yet: keep the illustration
    }
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
    _loadSchool();
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
    final api = context.read<AppState>().api;
    final photo = _school?['photo_url']?.toString();
    final logo = _school?['logo_url']?.toString();
    final name = (_school?['name'] ?? 'School').toString();
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.indigo,
      body: CustomPaint(
        painter: _LoginDots(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // school photo (uploaded by the admin in Odoo), or an illustration until then
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                child: SizedBox(
                  height: 330 + top,
                  child: photo != null
                      ? Image.network(api.url(photo), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _SchoolIllustration())
                      : const _SchoolIllustration(),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -42),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppColors.sun, width: 4),
                          boxShadow: const [BoxShadow(color: Color(0x38000000), blurRadius: 20, offset: Offset(0, 8))],
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.all(6),
                        child: logo != null
                            ? Image.network(api.url(logo),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 40, color: AppColors.indigo))
                            : const Icon(Icons.school_rounded, size: 40, color: AppColors.indigo),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: headingStyle(size: 25, color: Colors.white), maxLines: 2),
                              const Text('Parents · Students · Teachers',
                                  style: TextStyle(color: Color(0xFFDCDDFB), fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
                        ),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Welcome back', style: headingStyle(size: 24)),
                              const Text('Use the login given by your school office.',
                                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 14),
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: AppColors.soft(AppColors.rose), borderRadius: BorderRadius.circular(12)),
                                  child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _login,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                decoration: const InputDecoration(
                                    labelText: 'Mobile number or email', prefixIcon: Icon(Icons.person_outline_rounded)),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your login' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _password,
                                obscureText: _hidePassword,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                                    icon: Icon(_hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                              ),
                              if (_showServer) ...[
                                const SizedBox(height: 12),
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
                              const SizedBox(height: 18),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  backgroundColor: AppColors.sun,
                                  foregroundColor: AppColors.ink,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                                ),
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink))
                                    : Text('Sign in', style: headingStyle(size: 19)),
                              ),
                              const SizedBox(height: 4),
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
                    ),
                  ),
                ),
              ),
              Text(context.watch<AppState>().serverUrl,
                  textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB9BCF2), fontSize: 12)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginDots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x24FFFFFF);
    for (double y = 9; y < size.height; y += 18) {
      for (double x = 9; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Colourful school building shown until the school uploads its own photo.
class _SchoolIllustration extends StatelessWidget {
  const _SchoolIllustration();

  @override
  Widget build(BuildContext context) {
    Widget box(double l, double b, double w, double h, Color c, {double r = 0}) => Positioned(
          left: l,
          bottom: b,
          child: Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r))),
        );
    return Container(
      color: const Color(0xFF8FD3FF),
      child: LayoutBuilder(builder: (context, c) {
        final mid = c.maxWidth / 2;
        return Stack(
          children: [
            Positioned(
                right: 36,
                top: 60,
                child: Container(
                    width: 70, height: 70, decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle))),
            box(28, c.maxHeight - 110, 90, 26, Colors.white.withAlpha(230), r: 99),
            box(70, c.maxHeight - 96, 50, 30, Colors.white.withAlpha(230), r: 99),
            box(0, 0, c.maxWidth, 100, const Color(0xFF5FC77F)),
            box(mid - 120, 90, 240, 130, AppColors.coral, r: 8),
            box(mid - 40, 205, 80, 60, const Color(0xFFF26B5B), r: 8),
            box(mid - 13, 228, 26, 26, Colors.white, r: 13),
            box(mid - 1, 262, 3, 40, AppColors.night),
            box(mid + 2, 288, 26, 14, AppColors.sun),
            for (final dx in [-95.0, -50.0, 20.0, 65.0]) box(mid + dx, 150, 30, 30, const Color(0xFFCFEFFF), r: 6),
            box(mid - 17, 90, 34, 50, AppColors.night, r: 4),
            box(18, 90, 10, 40, const Color(0xFF8A5A2B)),
            box(-2, 120, 50, 60, const Color(0xFF2E9E5B), r: 30),
            box(c.maxWidth - 32, 90, 10, 34, const Color(0xFF8A5A2B)),
            box(c.maxWidth - 52, 114, 50, 54, const Color(0xFF2E9E5B), r: 27),
          ],
        );
      }),
    );
  }
}
