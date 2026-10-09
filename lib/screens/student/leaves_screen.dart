import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key, required this.studentId});

  final int studentId;

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  int _version = 0;

  Future<void> _request() async {
    final created = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => _LeaveForm(studentId: widget.studentId)));
    if (created == true) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final myId = state.user['name'];
    return PageScaffold(
      title: 'Leave requests',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _request,
        icon: const Icon(Icons.add),
        label: const Text('Request leave'),
      ),
      body: AsyncView<dynamic>(
        reloadKey: _version,
        loader: () => state.api.get('/students/${widget.studentId}/leaves', query: {'limit': '50'}),
        builder: (context, data, reload) {
          final items = (data['items'] as List? ?? const []).cast<Map>();
          if (items.isEmpty) {
            return const EmptyView(
                icon: Icons.event_available, message: 'No leave requests yet.', color: AppColors.sky);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final leave = items[i];
              final canCancel = leave['state'] == 'to_approve' && leave['requested_by'] == myId;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconTile(icon: Icons.event_busy_rounded, color: AppColors.sky, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${fmtDate(leave['date_from'], year: false)} → ${fmtDate(leave['date_to'])}',
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${leave['days']} day(s)', style: const TextStyle(color: AppColors.muted)),
                            ],
                          ),
                        ),
                        StatusChip(label: (leave['state_label'] ?? '').toString(), status: leave['state']?.toString()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text((leave['reason'] ?? '').toString()),
                    if (leave['approved_by'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('By ${leave['approved_by']}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ),
                    if (canCancel)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            if (!await confirmDialog(context, 'Cancel request', 'Cancel this leave request?')) return;
                            if (!context.mounted) return;
                            final ok = await runAction(context, () async {
                              await state.api.post('/students/${widget.studentId}/leaves/${leave['id']}/cancel');
                            }, success: 'Request cancelled');
                            if (ok) reload();
                          },
                          child: const Text('Cancel request'),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaveForm extends StatefulWidget {
  const _LeaveForm({required this.studentId});

  final int studentId;

  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked.isBefore(_from) ? _from : picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      showMessage(context, 'Please write the reason.', error: true);
      return;
    }
    setState(() => _busy = true);
    final api = context.read<AppState>().api;
    final ok = await runAction(context, () async {
      await api.post('/students/${widget.studentId}/leaves', {
        'date_from': isoDate(_from),
        'date_to': isoDate(_to),
        'reason': _reason.text.trim(),
      });
    }, success: 'Leave request sent to the class teacher');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final days = _to.difference(_from).inDays + 1;
    return PageScaffold(
      title: 'Request leave',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _DateBox(label: 'From', date: _from, onTap: () => _pick(true))),
              const SizedBox(width: 12),
              Expanded(child: _DateBox(label: 'To', date: _to, onTap: () => _pick(false))),
            ],
          ),
          const SizedBox(height: 8),
          Text('$days day(s)', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. Fever, family function'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(fmtDate(isoDate(date)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
