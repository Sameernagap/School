import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

String _leaveStatus(String state) => switch (state) {
      'validate' => 'approved',
      'refuse' => 'rejected',
      'cancel' => 'rejected',
      _ => 'to_approve',
    };

String _period(Map l) =>
    l['date_from'] == l['date_to'] ? fmtDate(l['date_from']) : '${fmtDate(l['date_from'], year: false)} – ${fmtDate(l['date_to'])}';

/// Staff leave: balances, my requests, apply; approvers also see requests to approve.
class StaffLeaveScreen extends StatefulWidget {
  const StaffLeaveScreen({super.key});

  @override
  State<StaffLeaveScreen> createState() => _StaffLeaveScreenState();
}

class _StaffLeaveScreenState extends State<StaffLeaveScreen> {
  Map<String, dynamic>? _data;
  List<Map> _approvals = [];
  String? _error;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = Map<String, dynamic>.from(await _api.get('/staff/leave') as Map);
      _approvals = data['can_approve'] == true
          ? ((await _api.get('/staff/leave/approvals')) as List).cast<Map>()
          : <Map>[];
      _data = data;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _apply() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _ApplyLeaveScreen(types: (_data!['types'] as List).cast<Map>())),
    );
    if (created == true) _load();
  }

  Future<void> _cancel(Map leave) async {
    if (!await confirmDialog(context, 'Cancel request', 'Cancel your ${leave['type']['name']} request for ${_period(leave)}?',
        ok: 'Cancel request')) {
      return;
    }
    if (!mounted) return;
    final ok = await runAction(context, () => _api.post('/staff/leave/${leave['id']}/cancel'), success: 'Request cancelled');
    if (ok) _load();
  }

  Future<void> _decide(Map leave, String decision) async {
    final ok = await runAction(context, () => _api.post('/staff/leave/${leave['id']}/$decision'),
        success: decision == 'approve' ? 'Leave approved' : 'Leave not approved');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return PageScaffold(
      title: 'My Leave',
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _apply,
              backgroundColor: const Color(0xFFFFC93C),
              foregroundColor: AppColors.ink,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Apply leave', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
      body: data == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (_approvals.isNotEmpty) ...[
                    SectionTitle('To approve (${_approvals.length})'),
                    for (final l in _approvals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          color: const Color(0xFFEEF0FF),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l['employee']['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('${l['type']['name']} · ${_period(l)} · ${l['duration']}',
                                  style: const TextStyle(color: AppColors.muted)),
                              if ((l['reason'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(l['reason'].toString()),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                        onPressed: () => _decide(l, 'refuse'), child: const Text('Not approve')),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                                      onPressed: () => _decide(l, 'approve'),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  if ((data['balances'] as List).isNotEmpty) ...[
                    const SectionTitle('Balance'),
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: (data['balances'] as List).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final b = (data['balances'] as List)[i] as Map;
                          final colors = [AppColors.indigo, AppColors.teal, AppColors.orange, AppColors.purple];
                          final c = colors[i % colors.length];
                          return Container(
                            width: 150,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.soft(c), borderRadius: BorderRadius.circular(18)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${b['remaining']}'.replaceAll(RegExp(r'\.0$'), ''),
                                    style: TextStyle(color: c, fontSize: 26, fontWeight: FontWeight.w800)),
                                Text('of ${'${b['total']}'.replaceAll(RegExp(r'\.0$'), '')} days left',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Text(b['name'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SectionTitle('My requests'),
                  if ((data['requests'] as List).isEmpty)
                    const EmptyView(icon: Icons.event_available_rounded, message: 'No leave requests yet.'),
                  for (final l in (data['requests'] as List).cast<Map>())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l['type']['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${_period(l)} · ${l['duration']}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                                ],
                              ),
                            ),
                            StatusChip(label: l['state_label'].toString(), status: _leaveStatus(l['state'].toString())),
                            if (l['can_cancel'] == true)
                              IconButton(
                                tooltip: 'Cancel request',
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () => _cancel(l),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ApplyLeaveScreen extends StatefulWidget {
  const _ApplyLeaveScreen({required this.types});

  final List<Map> types;

  @override
  State<_ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<_ApplyLeaveScreen> {
  int? _typeId;
  DateTime _from = DateTime.now().add(const Duration(days: 1));
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  String _period = 'full';
  final _reason = TextEditingController();
  bool _saving = false;

  Map? get _type => widget.types.where((t) => t['id'] == _typeId).firstOrNull;
  bool get _halfDayAllowed => _type?['unit'] == 'half_day' && isoDate(_from) == isoDate(_to);

  @override
  void initState() {
    super.initState();
    _typeId = widget.types.isNotEmpty ? widget.types.first['id'] as int : null;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (_typeId == null) return;
    if (_reason.text.trim().isEmpty) {
      showMessage(context, 'Please write a reason.', error: true);
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AppState>().api;
    final ok = await runAction(context, () async {
      await api.post('/staff/leave', {
        'type_id': _typeId,
        'date_from': isoDate(_from),
        'date_to': isoDate(_to),
        'reason': _reason.text.trim(),
        if (_halfDayAllowed && _period != 'full') 'period': _period,
      });
    }, success: 'Leave request sent to the principal');
    if (mounted) setState(() => _saving = false);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _type?['remaining'];
    return PageScaffold(
      title: 'Apply leave',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: _typeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Leave type'),
            items: [
              for (final t in widget.types)
                DropdownMenuItem(value: t['id'] as int, child: Text(t['name'].toString())),
            ],
            onChanged: (v) => setState(() => _typeId = v),
          ),
          if (remaining != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('$remaining days left'.replaceAll('.0 ', ' '),
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text('From ${fmtDate(isoDate(_from), year: false)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text('To ${fmtDate(isoDate(_to), year: false)}'),
                ),
              ),
            ],
          ),
          if (_halfDayAllowed) ...[
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'full', label: Text('Full day')),
                ButtonSegment(value: 'am', label: Text('Morning')),
                ButtonSegment(value: 'pm', label: Text('Afternoon')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.teal),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    );
  }
}
