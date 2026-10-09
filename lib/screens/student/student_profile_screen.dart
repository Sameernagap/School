import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Student profile',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId'),
        builder: (context, s, reload) {
          final parents = (s['parents'] as List? ?? const []).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Avatar(name: (s['name'] ?? '').toString(), photoUrl: s['photo_url'] as String?, radius: 34),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((s['name'] ?? '').toString(),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(s['admission_no']?.toString() ?? '', style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            StatusChip(label: nameOf(s['section']), color: AppColors.indigo),
                            if (s['roll_no'] != null) StatusChip(label: 'Roll ${s['roll_no']}', color: AppColors.sky),
                            if (s['house'] != null) StatusChip(label: nameOf(s['house']), color: AppColors.orange),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('School'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Academic year', nameOf(s['academic_year'])),
                    InfoRow('Class teacher', nameOf(s['class_teacher']).isEmpty ? '-' : nameOf(s['class_teacher'])),
                    InfoRow('Admission date', fmtDate(s['admission_date'])),
                    if (s['attendance_rate'] != null) InfoRow('Attendance', '${fmtNum(s['attendance_rate'])}%'),
                  ],
                ),
              ),
              const SectionTitle('Personal'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Date of birth', fmtDate(s['date_of_birth'])),
                    InfoRow('Gender', (s['gender'] ?? '-').toString()),
                    InfoRow('Blood group', (s['blood_group'] ?? '-').toString()),
                    InfoRow('Address', (s['address'] ?? '-').toString()),
                  ],
                ),
              ),
              if (parents.isNotEmpty) ...[
                const SectionTitle('Parents'),
                for (final p in parents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: [
                          Avatar(name: (p['name'] ?? '').toString(), color: AppColors.pink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((p['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${p['relation'] ?? ''}${p['phone'] != null ? ' · ${p['phone']}' : ''}',
                                    style: const TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          ),
                          if (p['phone'] != null)
                            IconButton.filledTonal(
                              onPressed: () => launchUrl(Uri.parse('tel:${p['phone'].toString().replaceAll(' ', '')}')),
                              icon: const Icon(Icons.call, size: 18),
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
