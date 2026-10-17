import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'diary_common.dart';

/// Teacher: today's diary status for each pre-primary class.
class TeacherDiaryScreen extends StatefulWidget {
  const TeacherDiaryScreen({super.key});

  @override
  State<TeacherDiaryScreen> createState() => _TeacherDiaryScreenState();
}

class _TeacherDiaryScreenState extends State<TeacherDiaryScreen> {
  DateTime _date = DateTime.now();
  int _version = 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final day = isoDate(_date);
    return PageScaffold(
      title: 'Daily Diary',
      actions: [
        TextButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(fmtDate(day, year: false)),
        ),
      ],
      body: AsyncView<dynamic>(
        reloadKey: '$day-$_version',
        loader: () => api.get('/teacher/diary', query: {'date': day}),
        builder: (context, data, reload) {
          final sections = ((data as Map)['sections'] as List? ?? const []).cast<Map>();
          if (sections.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              EmptyView(
                icon: Icons.menu_book_rounded,
                color: AppColors.rose,
                message: 'You have no pre-primary class. The daily diary is for Playgroup, Nursery, LKG and UKG.',
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = sections[i];
              final state = (row['state'] ?? 'none').toString();
              final label = state == 'sent' ? 'Sent' : (state == 'draft' ? 'Not sent yet' : 'Not started');
              final color = state == 'sent' ? AppColors.emerald : (state == 'draft' ? AppColors.amber : AppColors.slate);
              return AppCard(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DiaryFillScreen(sectionId: (row['section'] as Map)['id'] as int, date: day)),
                  );
                  setState(() => _version++);
                },
                child: Row(
                  children: [
                    const IconTile(icon: Icons.menu_book_rounded, color: AppColors.rose),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nameOf(row['section']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(
                            state == 'sent'
                                ? 'Seen by ${row['seen_count']} of ${row['present_count']} families'
                                : '${row['student_count']} children',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(label: label, color: color),
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

/// Teacher: fill the diary of one class for one day and send it to the parents.
class DiaryFillScreen extends StatefulWidget {
  const DiaryFillScreen({super.key, required this.sectionId, required this.date});

  final int sectionId;
  final String date;

  @override
  State<DiaryFillScreen> createState() => _DiaryFillScreenState();
}

class _DiaryFillScreenState extends State<DiaryFillScreen> {
  final _theme = TextEditingController();
  final _activity = TextEditingController();
  final _classNote = TextEditingController();
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _entries = [];
  String? _error;
  bool _busy = false;
  bool _dirty = false;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _theme.dispose();
    _activity.dispose();
    _classNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/teacher/diary', query: {'section_id': '${widget.sectionId}', 'date': widget.date});
      _apply(Map<String, dynamic>.from(data as Map));
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  void _apply(Map<String, dynamic> data) {
    _data = data;
    _theme.text = (data['theme'] ?? '').toString();
    _activity.text = (data['activity'] ?? '').toString();
    _classNote.text = (data['class_note'] ?? '').toString();
    _entries = (data['entries'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _dirty = false;
  }

  void _set(Map<String, dynamic> entry, String field, dynamic value) {
    setState(() {
      entry[field] = value;
      _dirty = true;
    });
  }

  void _setAll(String field, String value) {
    setState(() {
      for (final e in _entries) {
        if (e['is_absent'] != true) e[field] = value;
      }
      _dirty = true;
    });
  }

  Future<void> _save({required bool send}) async {
    setState(() => _busy = true);
    final sent = _data?['state'] == 'sent';
    final ok = await runAction(context, () async {
      final data = await _api.post('/teacher/diary', {
        'section_id': widget.sectionId,
        'date': widget.date,
        'theme': _theme.text,
        'activity': _activity.text,
        'class_note': _classNote.text,
        'entries': [
          for (final e in _entries)
            {
              'student_id': (e['student'] as Map)['id'],
              'is_absent': e['is_absent'] == true,
              'meal': e['meal'],
              'nap': e['nap'],
              'mood': e['mood'],
              'toilet': e['toilet'] ?? '',
              'note': e['note'] ?? '',
            }
        ],
        'send': send,
      });
      _apply(Map<String, dynamic>.from(data as Map));
    }, success: send ? (sent ? 'Update sent to parents' : 'Sent to parents') : 'Saved');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && send) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return PageScaffold(
        title: 'Diary',
        body: _error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final sent = data['state'] == 'sent';
    final present = _entries.where((e) => e['is_absent'] != true).length;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await confirmDialog(context, 'Leave without saving?', 'Your changes to the diary will be lost.',
            ok: 'Leave');
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: PageScaffold(
        title: nameOf(data['section']),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  Row(
                    children: [
                      Text(fmtDate(widget.date), style: headingStyle(size: 18)),
                      const Spacer(),
                      StatusChip(
                          label: sent ? 'Sent' : 'Not sent', color: sent ? AppColors.emerald : AppColors.amber),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('For the whole class', style: headingStyle(size: 16)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _theme,
                          onChanged: (_) => _dirty = true,
                          decoration: const InputDecoration(labelText: 'Theme / topic', hintText: 'e.g. Colour red'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _activity,
                          onChanged: (_) => _dirty = true,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              labelText: 'What we did today', hintText: 'e.g. Made a paper apple, story time'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _classNote,
                          onChanged: (_) => _dirty = true,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Note for all parents', hintText: 'e.g. Send extra clothes tomorrow'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Children', style: headingStyle(size: 18)),
                      const SizedBox(width: 8),
                      Text('$present present', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Everyone:', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
                      ActionChip(avatar: const Text('😋'), label: const Text('Ate all'), onPressed: () => _setAll('meal', 'all')),
                      ActionChip(avatar: const Text('😴'), label: const Text('Slept well'), onPressed: () => _setAll('nap', 'slept')),
                      ActionChip(avatar: const Text('😊'), label: const Text('Happy'), onPressed: () => _setAll('mood', 'happy')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final entry in _entries) ...[
                    _ChildEntry(
                        key: ValueKey((entry['student'] as Map)['id']),
                        entry: entry,
                        onChanged: (field, value) => _set(entry, field, value)),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _busy ? null : () => _save(send: false),
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 7,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.sun,
                            foregroundColor: AppColors.ink,
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: _busy || present == 0 ? null : () => _save(send: true),
                        icon: Icon(sent ? Icons.refresh_rounded : Icons.send_rounded),
                        label: Text(_busy ? 'Please wait…' : (sent ? 'Send update' : 'Send to parents')),
                      ),
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

/// One child: absent switch, meal / nap / mood choices, toilet and a personal note.
class _ChildEntry extends StatefulWidget {
  const _ChildEntry({super.key, required this.entry, required this.onChanged});

  final Map<String, dynamic> entry;
  final void Function(String field, dynamic value) onChanged;

  @override
  State<_ChildEntry> createState() => _ChildEntryState();
}

class _ChildEntryState extends State<_ChildEntry> {
  late final TextEditingController _note = TextEditingController(text: (widget.entry['note'] ?? '').toString());
  late final TextEditingController _toilet = TextEditingController(text: (widget.entry['toilet'] ?? '').toString());
  late bool _more = (widget.entry['note'] ?? '').toString().isNotEmpty || (widget.entry['toilet'] ?? '').toString().isNotEmpty;

  @override
  void didUpdateWidget(covariant _ChildEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    final note = (widget.entry['note'] ?? '').toString();
    final toilet = (widget.entry['toilet'] ?? '').toString();
    if (_note.text != note) _note.text = note;
    if (_toilet.text != toilet) _toilet.text = toilet;
  }

  @override
  void dispose() {
    _note.dispose();
    _toilet.dispose();
    super.dispose();
  }

  Widget _row(String field, Map<String, String> options, Color color, {Map<String, String>? emoji}) {
    final current = widget.entry[field] as String?;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options.entries)
          ChoicePill(
            label: option.value,
            emoji: emoji?[option.key],
            color: field == 'meal' ? mealColor(option.key) : color,
            selected: current == option.key,
            onTap: () => widget.onChanged(field, current == option.key ? null : option.key),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final student = entry['student'] as Map;
    final absent = entry['is_absent'] == true;
    final seen = entry['seen_on'] != null;
    final reply = (entry['parent_reply'] ?? '').toString();
    return AppCard(
      color: absent ? const Color(0xFFF3F4F8) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(name: (student['name'] ?? '').toString(), photoUrl: student['photo_url'] as String?, radius: 20, color: AppColors.rose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((student['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (seen)
                      const Text('✓ Seen by parent', style: TextStyle(color: AppColors.emerald, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Text('Absent', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
              Switch(value: absent, onChanged: (v) => widget.onChanged('is_absent', v)),
            ],
          ),
          if (!absent) ...[
            const SizedBox(height: 8),
            _row('mood', moodLabels, AppColors.indigo, emoji: moodEmoji),
            const SizedBox(height: 8),
            _row('meal', mealLabels, AppColors.emerald),
            const SizedBox(height: 8),
            _row('nap', napLabels, AppColors.violet),
            if (!_more)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _more = true),
                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                  label: const Text('Add a note'),
                ),
              )
            else ...[
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                onChanged: (v) => widget.onChanged('note', v),
                decoration: const InputDecoration(labelText: 'Note for parents', hintText: 'e.g. Did not eat lunch'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _toilet,
                onChanged: (v) => widget.onChanged('toilet', v),
                decoration: const InputDecoration(labelText: 'Toilet / diaper (optional)'),
              ),
            ],
          ],
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.soft(AppColors.emerald), borderRadius: BorderRadius.circular(12)),
              child: Text('Parent: “$reply”', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
