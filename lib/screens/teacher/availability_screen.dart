import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Teacher: when they cannot (or would rather not) teach. The office's timetable generator uses it.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _saving = false;
  bool _changed = false;

  /// "day|periodId" (periodId empty = whole day) -> 'unavailable' | 'avoid'
  final Map<String, String> _marks = {};

  static String _key(int day, int? periodId) => '$day|${periodId ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = Map<String, dynamic>.from(await context.read<AppState>().api.get('/teacher/availability') as Map);
      _marks.clear();
      for (final e in (data['entries'] as List).cast<Map>()) {
        _marks[_key(e['day'] as int, e['period_id'] as int?)] = e['kind'].toString();
      }
      if (mounted) setState(() {
        _data = data;
        _error = null;
        _changed = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _cycle(int day, int periodId) {
    final key = _key(day, periodId);
    setState(() {
      _changed = true;
      switch (_marks[key]) {
        case null:
          _marks[key] = 'avoid';
          break;
        case 'avoid':
          _marks[key] = 'unavailable';
          break;
        default:
          _marks.remove(key);
      }
    });
  }

  void _wholeDay(int day, bool off) {
    setState(() {
      _changed = true;
      if (off) {
        _marks[_key(day, null)] = 'unavailable';
      } else {
        _marks.remove(_key(day, null));
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final entries = _marks.entries.map((e) {
      final parts = e.key.split('|');
      return {
        'day': int.parse(parts[0]),
        'period_id': parts[1].isEmpty ? null : int.parse(parts[1]),
        'kind': e.value,
      };
    }).toList();
    final ok = await runAction(context, () async {
      await context.read<AppState>().api.post('/teacher/availability', {'entries': entries});
    }, success: 'Saved. The office will use this for the next timetable.');
    if (mounted) setState(() {
      _saving = false;
      if (ok) _changed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'My availability',
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : _content(),
    );
  }

  Widget _content() {
    final days = (_data!['days'] as List).cast<Map>();
    final periods = (_data!['periods'] as List).cast<Map>();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              const HeroHeader(
                color: AppColors.teacher,
                icon: Icons.event_available_rounded,
                title: 'When can you teach?',
                subtitle: 'Tap a period: free, rather not, not available. The office uses this when it makes the timetable.',
              ),
              const SizedBox(height: 12),
              const _Legend(),
              const SizedBox(height: 4),
              for (final d in days) _dayCard(d['day'] as int, d['label'].toString(), periods),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teacher, padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: _saving || !_changed ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : (_changed ? 'Save' : 'Saved')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCard(int day, String label, List<Map> periods) {
    final dayOff = _marks[_key(day, null)] == 'unavailable';
    final todays = periods.where((p) {
      final only = (p['days'] as List? ?? const []).cast<int>();
      return only.isEmpty || only.contains(day);
    }).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                const Text('Whole day off', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                Switch(
                  value: dayOff,
                  activeColor: AppColors.rose,
                  onChanged: (v) => _wholeDay(day, v),
                ),
              ],
            ),
            if (!dayOff)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in todays)
                    _PeriodChip(
                      name: p['name'].toString(),
                      time: p['start'].toString(),
                      kind: _marks[_key(day, p['id'] as int)],
                      onTap: () => _cycle(day, p['id'] as int),
                    ),
                ],
              )
            else
              const Text('Not available all day.', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.name, required this.time, required this.kind, required this.onTap});

  final String name;
  final String time;
  final String? kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg, fg, border;
    final String state;
    switch (kind) {
      case 'unavailable':
        bg = const Color(0xFFFFE4E6);
        fg = AppColors.rose;
        border = AppColors.rose;
        state = 'Not available';
        break;
      case 'avoid':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        border = AppColors.amber;
        state = 'Rather not';
        break;
      default:
        bg = Colors.white;
        fg = AppColors.ink;
        border = AppColors.line;
        state = 'Free';
    }
    return Semantics(
      button: true,
      label: '$name at $time: $state. Tap to change.',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 92, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
                Text(kind == null ? time : state, style: TextStyle(fontSize: 11.5, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color bg, Color border, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: border, width: 1.5)),
            ),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(Colors.white, AppColors.line, 'Free'),
        item(const Color(0xFFFEF3C7), AppColors.amber, 'Rather not'),
        item(const Color(0xFFFFE4E6), AppColors.rose, 'Not available'),
      ],
    );
  }
}
