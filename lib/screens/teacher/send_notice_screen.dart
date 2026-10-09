import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class SendNoticeScreen extends StatefulWidget {
  const SendNoticeScreen({super.key});

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _SendNoticeScreenState extends State<SendNoticeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<Map> _sections = [];
  final Set<int> _selected = {};
  String _type = 'general';
  bool _parents = true;
  bool _students = true;
  DateTime? _eventDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().api.get('/teacher/sections').then((data) {
      if (!mounted) return;
      setState(() {
        _sections = (data as List).cast<Map>();
        for (final s in _sections.where((s) => s['is_class_teacher'] == true)) {
          _selected.add(s['id'] as int);
        }
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _selected.isEmpty) {
      showMessage(context, 'Write a title and choose at least one section.', error: true);
      return;
    }
    if (!_parents && !_students) {
      showMessage(context, 'Send it to parents, students or both.', error: true);
      return;
    }
    setState(() => _busy = true);
    final api = context.read<AppState>().api;
    final ok = await runAction(context, () async {
      await api.post('/teacher/notices', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'section_ids': _selected.toList(),
        'type': _type,
        'for_parents': _parents,
        'for_students': _students,
        if (_eventDate != null) 'event_date': isoDate(_eventDate!),
        'publish': true,
      });
    }, success: 'Notice sent');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Send notice',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')),
          const SectionTitle('Type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const [
                ('general', 'General'),
                ('event', 'Event'),
                ('holiday', 'Holiday'),
                ('exam', 'Exam'),
                ('urgent', 'Urgent'),
              ])
                ChoiceChip(label: Text(t.$2), selected: _type == t.$1, onSelected: (_) => setState(() => _type = t.$1)),
            ],
          ),
          const SectionTitle('Sections'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sections)
                FilterChip(
                  label: Text((s['name'] ?? '').toString()),
                  selected: _selected.contains(s['id']),
                  onSelected: (v) => setState(() => v ? _selected.add(s['id'] as int) : _selected.remove(s['id'])),
                ),
            ],
          ),
          const SectionTitle('Send to'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(title: const Text('Parents'), value: _parents, onChanged: (v) => setState(() => _parents = v)),
                const Divider(height: 1),
                SwitchListTile(
                    title: const Text('Students'), value: _students, onChanged: (v) => setState(() => _students = v)),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Event date'),
                  subtitle: Text(_eventDate == null ? 'Optional' : fmtDate(isoDate(_eventDate!))),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.amber),
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_busy ? 'Sending…' : 'Send notice'),
          ),
        ],
      ),
    );
  }
}
