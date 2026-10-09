import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.studentId});

  final int studentId;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Attendance',
      body: AsyncView<dynamic>(
        reloadKey: _monthKey,
        loader: () => api.get('/students/${widget.studentId}/attendance', query: {'month': _monthKey}),
        builder: (context, data, reload) {
          final days = (data['days'] as List? ?? const []).cast<Map>();
          final summary = Map<String, dynamic>.from(data['summary'] as Map? ?? const {});
          final year = Map<String, dynamic>.from(data['year'] as Map? ?? const {});
          final byDate = <int, String>{};
          for (final d in days.where((d) => d['subject'] == null)) {
            final date = parseDate(d['date']);
            if (date != null) byDate[date.day] = (d['status'] ?? '').toString();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                color: AppColors.emerald,
                icon: Icons.fact_check_rounded,
                title: '${fmtNum(year['attendance_rate'] ?? 0)}% this year',
                subtitle: '${year['days_present'] ?? 0} days present · ${year['days_absent'] ?? 0} absent',
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                        Expanded(
                          child: Text(fmtMonth(_month),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                        IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _MonthGrid(month: _month, statuses: byDate),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusChip(label: 'Present ${summary['present'] ?? 0}', status: 'present'),
                        StatusChip(label: 'Absent ${summary['absent'] ?? 0}', status: 'absent'),
                        StatusChip(label: 'Late ${summary['late'] ?? 0}', status: 'late'),
                        StatusChip(label: 'Half day ${summary['half_day'] ?? 0}', status: 'half_day'),
                        StatusChip(label: 'Leave ${summary['leave'] ?? 0}', status: 'leave'),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionTitle('Details'),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No attendance recorded this month.', style: TextStyle(color: AppColors.muted)),
                ),
              for (final d in days.reversed)
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
                              Text(fmtDate(d['date']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (d['subject'] != null || d['remark'] != null)
                                Text(
                                  [nameOf(d['subject']), (d['remark'] ?? '').toString()]
                                      .where((t) => t.isNotEmpty)
                                      .join(' · '),
                                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        StatusChip(label: (d['status_label'] ?? d['status']).toString(), status: d['status']?.toString()),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.statuses});

  final DateTime month;
  final Map<int, String> statuses;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1; // Monday first
    final cells = <Widget>[
      for (final w in weekdaysShort)
        Center(child: Text(w.substring(0, 1), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++) _cell(day),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }

  Widget _cell(int day) {
    final status = statuses[day];
    final color = status != null ? statusColor(status) : null;
    final weekday = DateTime(month.year, month.month, day).weekday;
    return Container(
      decoration: BoxDecoration(
        color: color ?? (weekday == DateTime.sunday ? const Color(0xFFF1F5F9) : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          color: color != null ? Colors.white : AppColors.ink,
          fontWeight: color != null ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}
