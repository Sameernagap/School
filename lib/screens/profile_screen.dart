import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final school = state.school;
    final year = school['academic_year'] is Map ? school['academic_year'] as Map : null;
    return PageScaffold(
      title: 'Profile',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                Avatar(name: (user['name'] ?? '').toString(), radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((user['name'] ?? '').toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      Text((user['login'] ?? '').toString(), style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        for (final role in state.roles) StatusChip(label: role[0].toUpperCase() + role.substring(1), color: AppColors.indigo),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('School'),
          AppCard(
            child: Column(
              children: [
                InfoRow('Name', (school['name'] ?? '-').toString()),
                if (year != null) InfoRow('Academic year', (year['name'] ?? '-').toString()),
                if (school['phone'] != null) InfoRow('Phone', school['phone'].toString()),
                if (school['email'] != null) InfoRow('Email', school['email'].toString()),
                InfoRow('Server', state.serverUrl),
              ],
            ),
          ),
          const SectionTitle('Account'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: AppColors.indigo),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.rose),
                  title: const Text('Sign out', style: TextStyle(color: AppColors.rose)),
                  onTap: () async {
                    if (await confirmDialog(context, 'Sign out', 'Sign out of the school app on this phone?',
                        ok: 'Sign out')) {
                      await state.logout();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('$appName app $appVersion', style: TextStyle(color: AppColors.muted, fontSize: 12))),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_new.text.length < 8) {
      showMessage(context, 'The new password needs at least 8 characters.', error: true);
      return;
    }
    if (_new.text != _confirm.text) {
      showMessage(context, 'The new passwords do not match.', error: true);
      return;
    }
    setState(() => _busy = true);
    final api = context.read<AppState>().api;
    final ok = await runAction(context, () async {
      await api.post('/auth/password/change', {'old_password': _old.text, 'new_password': _new.text});
    }, success: 'Password changed. Other devices were signed out.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Change password',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 12),
          TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
          const SizedBox(height: 12),
          TextField(
              controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Repeat new password')),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Change password'),
          ),
        ],
      ),
    );
  }
}
