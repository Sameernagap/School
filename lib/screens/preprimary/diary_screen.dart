import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'diary_common.dart';

/// Parent / student: the child's daily diary (meal, nap, mood, activity, teacher's note).
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.studentId, this.date});

  final int studentId;
  final String? date;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  String? _date;
  bool _loading = true;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _load();
  }

  Future<void> _load([String? date]) async {
    setState(() {
      _loading = true;
      if (date != null) _date = date;
    });
    try {
      final data = await _api.get('/students/${widget.studentId}/diary', query: {if (_date != null) 'date': _date!});
      _data = Map<String, dynamic>.from(data as Map);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    Widget body;
    if (data == null) {
      body = _loading
          ? const Center(child: CircularProgressIndicator())
          : ErrorView(message: _error ?? 'Could not load the diary.', onRetry: _load);
    } else {
      final diary = data['diary'] is Map ? Map<String, dynamic>.from(data['diary'] as Map) : null;
      final recent = (data['recent'] as List? ?? const []).cast<Map>();
      body = RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            if (recent.isNotEmpty) _RecentStrip(recent: recent, selected: diary?['date'] as String?, onPick: _load),
            const SizedBox(height: 12),
            if (diary == null)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyView(
                  icon: Icons.menu_book_rounded,
                  color: AppColors.rose,
                  message: 'No diary yet. The teacher sends it at the end of the school day.',
                ),
              )
            else ...[
              _DayHeader(diary: diary, onPick: _load),
              const SizedBox(height: 12),
              _ChildCard(entry: Map<String, dynamic>.from(diary['entry'] as Map), name: _firstName(data)),
              const SizedBox(height: 12),
              _ClassCard(diary: diary),
              if (context.read<AppState>().isParent && diary['entry'] is Map && (diary['entry'] as Map)['is_absent'] != true)
                _ReplyBox(
                  key: ValueKey('reply-${(diary['entry'] as Map)['id']}'),
                  studentId: widget.studentId,
                  entry: Map<String, dynamic>.from(diary['entry'] as Map),
                  onReplied: () => _load(),
                ),
            ],
          ],
        ),
      );
    }
    return PageScaffold(title: 'Daily Diary', body: body);
  }

  String _firstName(Map<String, dynamic> data) {
    final student = data['student'] is Map ? data['student'] as Map : const {};
    final name = (student['name'] ?? '').toString().trim();
    return name.isEmpty ? 'Your child' : name.split(' ').first;
  }
}

/// Last school days as small mood bubbles; tap to open that day.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.recent, required this.selected, required this.onPick});

  final List<Map> recent;
  final String? selected;
  final void Function(String date) onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = recent[i];
          final date = (day['date'] ?? '').toString();
          final active = date == selected;
          final d = parseDate(date);
          final emoji = day['is_absent'] == true ? '—' : (moodEmoji[day['mood']] ?? '•');
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onPick(date),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: active ? AppColors.indigo : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(d == null ? '' : weekdaysShort[d.weekday - 1],
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white70 : AppColors.muted)),
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  Text(d == null ? '' : '${d.day}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.ink)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.diary, required this.onPick});

  final Map<String, dynamic> diary;
  final void Function(String date) onPick;

  @override
  Widget build(BuildContext context) {
    final prev = diary['prev_date'] as String?;
    final next = diary['next_date'] as String?;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: prev == null ? null : () => onPick(prev),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(fmtDate(diary['date']), style: headingStyle(size: 20)),
              Text(nameOf(diary['section']), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: next == null ? null : () => onPick(next),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Meal, nap, mood and the teacher's personal note for this child.
class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.entry, required this.name});

  final Map<String, dynamic> entry;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (entry['is_absent'] == true) {
      return AppCard(
        color: const Color(0xFFFFF4D6),
        child: Row(
          children: [
            const Text('🏠', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$name was absent on this day.',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF8A5A00))),
            ),
          ],
        ),
      );
    }
    final mood = entry['mood'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.rose,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$name's day", style: headingStyle(size: 22, color: Colors.white)),
                    Text(mood == null ? 'At school today' : 'Feeling ${(moodLabels[mood] ?? mood).toLowerCase()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
                child: Text(moodEmoji[mood] ?? '🙂', style: const TextStyle(fontSize: 34)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Fact(icon: Icons.restaurant_rounded, label: 'Meal', value: entry['meal_label'] as String?),
              const SizedBox(width: 8),
              _Fact(icon: Icons.bedtime_rounded, label: 'Nap', value: entry['nap_label'] as String?),
            ],
          ),
          if ((entry['toilet'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [_Fact(icon: Icons.wc_rounded, label: 'Toilet', value: entry['toilet'] as String?)]),
          ],
          if ((entry['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_rounded, color: AppColors.rose, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry['note'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.35)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  Text(value ?? '-',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the whole class did, and the note for all parents.
class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.diary});

  final Map<String, dynamic> diary;

  @override
  Widget build(BuildContext context) {
    final theme = (diary['theme'] ?? '').toString();
    final activity = (diary['activity'] ?? '').toString();
    final note = (diary['class_note'] ?? '').toString();
    if (theme.isEmpty && activity.isEmpty && note.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.palette_rounded, color: AppColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In class today', style: headingStyle(size: 17)),
                    if (theme.isNotEmpty)
                      Text(theme, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          if (activity.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(activity, style: const TextStyle(fontSize: 14.5, height: 1.4)),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(14)),
              child: Text('📌 $note',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7A4B00), height: 1.35)),
            ),
          ],
          if (diary['teacher'] is Map) ...[
            const SizedBox(height: 10),
            Text('— ${nameOf(diary['teacher'])}',
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

/// Short reply to the teacher ("Okay, noted"), or the reply already sent.
class _ReplyBox extends StatefulWidget {
  const _ReplyBox({super.key, required this.studentId, required this.entry, required this.onReplied});

  final int studentId;
  final Map<String, dynamic> entry;
  final VoidCallback onReplied;

  @override
  State<_ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<_ReplyBox> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await runAction(context, () async {
      await context.read<AppState>().api.post(
          '/students/${widget.studentId}/diary/${widget.entry['id']}/reply', {'reply': text.trim()});
    }, success: 'Sent to the teacher');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onReplied();
  }

  @override
  Widget build(BuildContext context) {
    final reply = (widget.entry['parent_reply'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        child: reply.isNotEmpty
            ? Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('You replied: “$reply”', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Reply to the teacher', style: headingStyle(size: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final quick in const ['Okay, noted 👍', 'Thank you! 🙏', 'Will send tomorrow'])
                        ActionChip(label: Text(quick), onPressed: _busy ? null : () => _send(quick)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLength: 300,
                          decoration: const InputDecoration(hintText: 'Write a message', counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _busy ? null : () => _send(_controller.text),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
