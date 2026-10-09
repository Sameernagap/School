import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class MarksheetsScreen extends StatefulWidget {
  const MarksheetsScreen({super.key});

  @override
  State<MarksheetsScreen> createState() => _MarksheetsScreenState();
}

class _MarksheetsScreenState extends State<MarksheetsScreen> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Marks entry',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(label: const Text('Show all'), selected: _all, onSelected: (v) => setState(() => _all = v)),
        ),
      ],
      body: AsyncView<dynamic>(
        reloadKey: _all,
        loader: () => api.get('/teacher/marksheets', query: {'state': _all ? 'all' : 'draft', 'limit': '100'}),
        builder: (context, data, reload) {
          final items = (data['items'] as List? ?? const []).cast<Map>();
          if (items.isEmpty) {
            return const EmptyView(
                icon: Icons.assignment_turned_in_outlined,
                message: 'No marks to enter right now.',
                color: AppColors.purple);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = items[i];
              final students = (m['students'] ?? 0) as int;
              final entered = (m['entered'] ?? 0) as int;
              return AppCard(
                onTap: () async {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => MarksEntryScreen(marksheetId: m['id'] as int)));
                  reload();
                },
                child: Row(
                  children: [
                    const IconTile(icon: Icons.assignment_rounded, color: AppColors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nameOf(m['exam']),
                              style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700, fontSize: 12)),
                          Text('${nameOf(m['subject'])} · ${nameOf(m['section'])}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('$entered of $students entered · max ${fmtNum(m['max_marks'])}',
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: m['state'] == 'submitted' ? 'Submitted' : 'To enter',
                      status: m['state'] == 'submitted' ? 'done' : 'pending',
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

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key, required this.marksheetId});

  final int marksheetId;

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  Map<String, dynamic>? _sheet;
  String? _error;
  bool _saving = false;
  final Map<int, TextEditingController> _marks = {};
  final Map<int, bool> _absent = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _marks.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppState>().api.get('/teacher/marksheets/${widget.marksheetId}');
      _apply(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _apply(Map<String, dynamic> sheet) {
    for (final line in (sheet['lines'] as List).cast<Map>()) {
      final id = line['student_id'] as int;
      final controller = _marks.putIfAbsent(id, () => TextEditingController());
      controller.text = line['marks'] == null ? '' : fmtNum(line['marks']);
      _absent[id] = line['absent'] == true;
    }
    setState(() {
      _sheet = sheet;
      _error = null;
    });
  }

  Future<void> _save({required bool submit}) async {
    final sheet = _sheet!;
    final max = ((sheet['max_marks'] ?? 0) as num).toDouble();
    final lines = <Map<String, dynamic>>[];
    for (final entry in _marks.entries) {
      if (_absent[entry.key] == true) {
        lines.add({'student_id': entry.key, 'absent': true});
        continue;
      }
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null || value < 0 || value > max) {
        showMessage(context, 'Marks must be between 0 and ${fmtNum(max)}.', error: true);
        return;
      }
      lines.add({'student_id': entry.key, 'marks': value});
    }
    if (submit) {
      final missing = _marks.entries.where((e) => _absent[e.key] != true && e.value.text.trim().isEmpty).length;
      if (missing > 0) {
        showMessage(context, 'Enter marks (or mark absent) for $missing more student(s).', error: true);
        return;
      }
      if (!await confirmDialog(
          context, 'Submit marks', 'After submitting, only the administrator can change these marks.',
          ok: 'Submit')) {
        return;
      }
    }
    setState(() => _saving = true);
    final api = context.read<AppState>().api;
    final ok = await runAction(context, () async {
      final data = await api.post('/teacher/marksheets/${widget.marksheetId}', {'lines': lines, 'submit': submit});
      _apply(Map<String, dynamic>.from(data as Map));
    }, success: submit ? 'Marks submitted' : 'Marks saved');
    if (mounted) setState(() => _saving = false);
    if (ok && submit && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (_error != null) return PageScaffold(title: 'Marks', body: ErrorView(message: _error!, onRetry: _load));
    if (sheet == null) return const PageScaffold(title: 'Marks', body: Center(child: CircularProgressIndicator()));
    final editable = sheet['editable'] == true;
    final lines = (sheet['lines'] as List).cast<Map>();
    return PageScaffold(
      title: '${nameOf(sheet['subject'])} marks',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: HeroHeader(
              color: AppColors.purple,
              icon: Icons.assignment_rounded,
              title: '${nameOf(sheet['subject'])} · ${nameOf(sheet['section'])}',
              subtitle:
                  '${nameOf(sheet['exam'])} · max ${fmtNum(sheet['max_marks'])} · pass ${fmtNum(sheet['pass_marks'])}',
            ),
          ),
          if (!editable)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('These marks are read-only.', style: TextStyle(color: AppColors.muted)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: lines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final line = lines[i];
                final id = line['student_id'] as int;
                final absent = _absent[id] == true;
                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${line['roll_no'] ?? ''}',
                            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((line['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (line['grade'] != null)
                              Text('Grade ${line['grade']}', style: const TextStyle(color: AppColors.purple, fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 78,
                        child: TextField(
                          controller: _marks[id],
                          enabled: editable && !absent,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: InputDecoration(
                            hintText: absent ? 'AB' : '-',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        children: [
                          Switch(
                            value: absent,
                            activeColor: AppColors.rose,
                            onChanged: editable ? (v) => setState(() => _absent[id] = v) : null,
                          ),
                          const Text('Absent', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (editable)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        onPressed: _saving ? null : () => _save(submit: false),
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.purple),
                        onPressed: _saving ? null : () => _save(submit: true),
                        child: Text(_saving ? 'Saving…' : 'Submit marks'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
