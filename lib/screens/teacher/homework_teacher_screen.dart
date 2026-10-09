import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class TeacherHomeworkScreen extends StatefulWidget {
  const TeacherHomeworkScreen({super.key});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Homework',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.pink,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const _NewHomework()));
          if (created == true) setState(() => _version++);
        },
        icon: const Icon(Icons.add),
        label: const Text('Give homework'),
      ),
      body: AsyncView<dynamic>(
        reloadKey: _version,
        loader: () => api.get('/teacher/homework', query: {'limit': '50'}),
        builder: (context, data, reload) {
          final items = (data['items'] as List? ?? const []).cast<Map>();
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.edit_note, message: 'You have not given homework yet.', color: AppColors.pink);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final hw = items[i];
              final rate = ((hw['submission_rate'] ?? 0) as num).toDouble();
              return AppCard(
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TeacherHomeworkDetail(homeworkId: hw['id'] as int)));
                  reload();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${nameOf(hw['section'])} · ${nameOf(hw['subject'])}',
                              style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        StatusChip(label: (hw['state'] ?? '').toString(), status: hw['state'] == 'assigned' ? 'pending' : 'done'),
                      ],
                    ),
                    Text((hw['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Due ${fmtDate(hw['due_date'])} · ${hw['submitted']}/${hw['total']} submitted',
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (rate / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: AppColors.pink,
                        backgroundColor: AppColors.soft(AppColors.pink),
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

class _NewHomework extends StatefulWidget {
  const _NewHomework();

  @override
  State<_NewHomework> createState() => _NewHomeworkState();
}

class _NewHomeworkState extends State<_NewHomework> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  List<Map> _sections = [];
  int? _sectionId;
  int? _subjectId;
  DateTime _due = DateTime.now().add(const Duration(days: 2));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().api.get('/teacher/sections').then((data) {
      if (!mounted) return;
      setState(() {
        _sections = (data as List).cast<Map>();
        if (_sections.isNotEmpty) {
          _sectionId = _sections.first['id'] as int;
          _pickFirstSubject();
        }
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  List<Map> get _subjects {
    final section = _sections.where((s) => s['id'] == _sectionId).toList();
    if (section.isEmpty) return [];
    return (section.first['subjects'] as List? ?? const []).cast<Map>();
  }

  void _pickFirstSubject() {
    final subjects = _subjects;
    _subjectId = subjects.isNotEmpty ? subjects.first['id'] as int : null;
  }

  Future<void> _save() async {
    if (_sectionId == null || _subjectId == null || _title.text.trim().isEmpty) {
      showMessage(context, 'Choose the section and subject and write a title.', error: true);
      return;
    }
    setState(() => _busy = true);
    final api = context.read<AppState>().api;
    final ok = await runAction(context, () async {
      await api.post('/teacher/homework', {
        'section_id': _sectionId,
        'subject_id': _subjectId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'due_date': isoDate(_due),
        'assign': true,
      });
    }, success: 'Homework sent to students and parents');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _subjects;
    return PageScaffold(
      title: 'Give homework',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: _sectionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Section'),
            items: [
              for (final s in _sections) DropdownMenuItem(value: s['id'] as int, child: Text((s['name'] ?? '').toString())),
            ],
            onChanged: (v) => setState(() {
              _sectionId = v;
              _pickFirstSubject();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('subjects-$_sectionId'),
            value: _subjectId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Subject',
              helperText: subjects.isEmpty ? 'You are not the subject teacher of this section.' : null,
            ),
            items: [
              for (final s in subjects) DropdownMenuItem(value: s['id'] as int, child: Text((s['name'] ?? '').toString())),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Exercise 3.2')),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'What should students do?'),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _due,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _due = picked);
            },
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.pink),
                const SizedBox(width: 10),
                Text('Due ${fmtDate(isoDate(_due))}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.edit_calendar, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.pink),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Sending…' : 'Give homework'),
          ),
        ],
      ),
    );
  }
}

class TeacherHomeworkDetail extends StatefulWidget {
  const TeacherHomeworkDetail({super.key, required this.homeworkId});

  final int homeworkId;

  @override
  State<TeacherHomeworkDetail> createState() => _TeacherHomeworkDetailState();
}

class _TeacherHomeworkDetailState extends State<TeacherHomeworkDetail> {
  Map<String, dynamic>? _hw;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppState>().api.get('/teacher/homework/${widget.homeworkId}');
      setState(() {
        _hw = Map<String, dynamic>.from(data as Map);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _update(int studentId, String status) async {
    final api = context.read<AppState>().api;
    await runAction(context, () async {
      final data = await api.post('/teacher/homework/${widget.homeworkId}/submissions', {
        'updates': [
          {'student_id': studentId, 'status': status},
        ],
      });
      setState(() => _hw = Map<String, dynamic>.from(data as Map));
    });
  }

  @override
  Widget build(BuildContext context) {
    final hw = _hw;
    return PageScaffold(
      title: 'Submissions',
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : hw == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      HeroHeader(
                        color: AppColors.pink,
                        icon: Icons.edit_note_rounded,
                        title: (hw['title'] ?? '').toString(),
                        subtitle:
                            '${nameOf(hw['section'])} · due ${fmtDate(hw['due_date'])} · ${hw['submitted']}/${hw['total']} in',
                      ),
                      const SizedBox(height: 12),
                      for (final s in (hw['submissions'] as List? ?? const []).cast<Map>())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((s['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      StatusChip(
                                          label: (s['status_label'] ?? '').toString(), status: s['status']?.toString()),
                                    ],
                                  ),
                                ),
                                if (hw['state'] == 'assigned') ...[
                                  if (s['status'] == 'pending')
                                    TextButton(
                                        onPressed: () => _update(s['student_id'] as int, 'submitted'),
                                        child: const Text('Submitted')),
                                  if (s['status'] != 'checked')
                                    IconButton.filledTonal(
                                      tooltip: 'Checked',
                                      onPressed: () => _update(s['student_id'] as int, 'checked'),
                                      icon: const Icon(Icons.done_all, size: 18),
                                    ),
                                  if (s['status'] != 'pending')
                                    IconButton(
                                      tooltip: 'Undo',
                                      onPressed: () => _update(s['student_id'] as int, 'pending'),
                                      icon: const Icon(Icons.undo, size: 18),
                                    ),
                                ],
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
