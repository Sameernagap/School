import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Exams & Results',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/exams'),
        builder: (context, data, reload) {
          final upcoming = (data['upcoming'] as List? ?? const []).cast<Map>();
          final results = (data['results'] as List? ?? const []).cast<Map>();
          if (upcoming.isEmpty && results.isEmpty) {
            return const EmptyView(
                icon: Icons.emoji_events_outlined, message: 'No exams scheduled yet.', color: AppColors.purple);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (results.isNotEmpty) ...[
                const SectionTitle('Results'),
                for (final r in results) _ResultCard(studentId: studentId, result: r),
              ],
              if (upcoming.isNotEmpty) ...[
                const SectionTitle('Date sheet'),
                for (final p in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                                color: AppColors.soft(AppColors.purple), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                Text('${parseDate(p['date'])?.day ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.purple)),
                                Text(fmtDate(p['date'], year: false).split(' ').last,
                                    style: const TextStyle(color: AppColors.purple, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nameOf(p['subject']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(nameOf(p['exam']), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (p['start'] != null)
                                Text('${p['start']} - ${p['end'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Max ${fmtNum(p['max_marks'])}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.studentId, required this.result});

  final int studentId;
  final Map result;

  @override
  Widget build(BuildContext context) {
    final passed = result['result'] == 'pass';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(studentId: studentId, resultId: result['id'] as int)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text((result['grade'] ?? '-').toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameOf(result['exam']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('${fmtNum(result['total'])} / ${fmtNum(result['max_total'])} · ${fmtNum(result['percentage'])}%',
                      style: const TextStyle(color: AppColors.muted)),
                  if (result['rank_section'] != null)
                    Text('Rank ${result['rank_section']} in section',
                        style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            StatusChip(label: passed ? 'Pass' : (result['result'] == 'absent' ? 'Absent' : 'Fail'),
                status: result['result']?.toString()),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.studentId, required this.resultId});

  final int studentId;
  final int resultId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Result',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/results/$resultId'),
        builder: (context, r, reload) {
          final subjects = (r['subjects'] as List? ?? const []).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                color: AppColors.purple,
                icon: Icons.emoji_events_rounded,
                title: '${fmtNum(r['percentage'])}% · Grade ${r['grade'] ?? '-'}',
                subtitle: '${nameOf(r['exam'])} · ${fmtNum(r['total'])}/${fmtNum(r['max_total'])} marks',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metric('Section rank', '${r['rank_section'] ?? '-'}'),
                  const SizedBox(width: 10),
                  _metric('Class rank', '${r['rank_class'] ?? '-'}'),
                  const SizedBox(width: 10),
                  _metric('Attendance', r['attendance_rate'] == null ? '-' : '${fmtNum(r['attendance_rate'])}%'),
                ],
              ),
              const SectionTitle('Subjects'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    for (final s in subjects)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(nameOf(s['subject']), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text(
                              s['absent'] == true ? 'Absent' : '${fmtNum(s['marks'])} / ${fmtNum(s['max_marks'])}',
                              style: TextStyle(
                                color: s['passed'] == true ? AppColors.ink : AppColors.rose,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 36,
                              child: Text((s['grade'] ?? '').toString(),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (r['remark'] != null) ...[
                const SectionTitle("Class teacher's remark"),
                AppCard(color: AppColors.soft(AppColors.amber), child: Text(r['remark'].toString())),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.purple),
                onPressed: () => openRemoteFile(context, r['report_card_url'].toString(), 'Report card ${nameOf(r['exam'])}.pdf'),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download report card'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );
}
