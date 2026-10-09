import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

const _statuses = [
  ('present', 'P', 'Present'),
  ('absent', 'A', 'Absent'),
  ('late', 'L', 'Late'),
  ('half_day', 'H', 'Half day'),
  ('leave', 'Lv', 'Leave'),
];

/// Pick a section and a date, then mark each student.
class AttendanceTakeScreen extends StatefulWidget {
  const AttendanceTakeScreen({super.key});

  @override
  State<AttendanceTakeScreen> createState() => _AttendanceTakeScreenState();
}

class _AttendanceTakeScreenState extends State<AttendanceTakeScreen> {
  List<Map> _sections = [];
  int? _sectionId;
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _sheet;
  final Map<int, String> _status = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final data = await _api.get('/teacher/sections');
      _sections = (data as List).cast<Map>();
      final mine = _sections.where((s) => s['is_class_teacher'] == true).toList();
      _sectionId = (mine.isNotEmpty ? mine.first : (_sections.isNotEmpty ? _sections.first : null))?['id'] as int?;
      if (_sectionId != null) {
        await _openSheet();
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openSheet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.post('/teacher/attendance/open', {'section_id': _sectionId, 'date': isoDate(_date)});
      _setSheet(Map<String, dynamic>.from(data as Map));
    } on ApiException catch (e) {
      _error = e.message;
      _sheet = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _setSheet(Map<String, dynamic> sheet) {
    _sheet = sheet;
    _status.clear();
    for (final line in (sheet['lines'] as List).cast<Map>()) {
      _status[line['student_id'] as int] = (line['status'] ?? 'present').toString();
    }
  }

  Future<void> _save({required bool submit}) async {
    if (_sheet == null) return;
    if (submit &&
        !await confirmDialog(context, 'Submit attendance',
            'Parents of absent and late students will be notified. Submit now?',
            ok: 'Submit')) {
      return;
    }
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      final data = await _api.post('/teacher/attendance/${_sheet!['id']}', {
        'lines': [
          for (final entry in _status.entries) {'student_id': entry.key, 'status': entry.value},
        ],
        'submit': submit,
      });
      _setSheet(Map<String, dynamic>.from(data as Map));
    }, success: submit ? 'Attendance submitted' : 'Saved');
    if (mounted) setState(() => _saving = false);
    if (ok && submit && mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _date = picked;
      await _openSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _sheet?['state'] == 'done';
    final lines = (_sheet?['lines'] as List? ?? const []).cast<Map>();
    final absent = _status.values.where((s) => s == 'absent').length;
    return PageScaffold(
      title: 'Attendance',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _sectionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: [
                      for (final s in _sections)
                        DropdownMenuItem(value: s['id'] as int, child: Text((s['name'] ?? '').toString())),
                    ],
                    onChanged: (v) {
                      _sectionId = v;
                      _openSheet();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(isoDate(_date), year: false)),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: ErrorView(message: _error!, onRetry: _openSheet))
          else if (_sheet == null)
            const Expanded(child: EmptyView(icon: Icons.groups_outlined, message: 'Choose a section.'))
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  StatusChip(label: '${lines.length} students', color: AppColors.indigo),
                  const SizedBox(width: 8),
                  StatusChip(label: '$absent absent', status: 'absent'),
                  const Spacer(),
                  if (done)
                    const StatusChip(label: 'Submitted', status: 'done')
                  else
                    TextButton(
                      onPressed: () => setState(() {
                        for (final key in _status.keys.toList()) {
                          if (_status[key] != 'leave') _status[key] = 'present';
                        }
                      }),
                      child: const Text('All present'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final line = lines[i];
                  final id = line['student_id'] as int;
                  final current = _status[id] ?? 'present';
                  return AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${line['roll_no'] ?? ''}',
                              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Text((line['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        for (final s in _statuses.take(3))
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _StatusButton(
                              label: s.$2,
                              tooltip: s.$3,
                              selected: current == s.$1,
                              color: statusColor(s.$1),
                              onTap: done ? null : () => setState(() => _status[id] = s.$1),
                            ),
                          ),
                        PopupMenuButton<String>(
                          enabled: !done,
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (v) => setState(() => _status[id] = v),
                          itemBuilder: (_) => [
                            for (final s in _statuses) PopupMenuItem(value: s.$1, child: Text(s.$3)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (!done)
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
                          child: const Text('Save draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.emerald),
                          onPressed: _saving ? null : () => _save(submit: true),
                          child: Text(_saving ? 'Saving…' : 'Submit attendance'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton(
      {required this.label, required this.tooltip, required this.selected, required this.color, required this.onTap});

  final String label;
  final String tooltip;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : AppColors.soft(color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }
}
