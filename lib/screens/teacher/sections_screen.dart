import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../student/student_profile_screen.dart';

class SectionsScreen extends StatelessWidget {
  const SectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'My classes',
      body: AsyncView<dynamic>(
        loader: () => api.get('/teacher/sections'),
        builder: (context, data, reload) {
          final sections = (data as List? ?? const []).cast<Map>();
          if (sections.isEmpty) {
            return const EmptyView(icon: Icons.groups_outlined, message: 'No sections are assigned to you yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = sections[i];
              final subjects = (s['subjects'] as List? ?? const []).map(nameOf).join(', ');
              return AppCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SectionStudentsScreen(sectionId: s['id'] as int, title: (s['name'] ?? '').toString())),
                ),
                child: Row(
                  children: [
                    const IconTile(icon: Icons.groups_rounded, color: AppColors.indigo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((s['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(
                            [
                              '${s['student_count']} students',
                              if (subjects.isNotEmpty) subjects,
                              if (s['room_no'] != null) 'Room ${s['room_no']}',
                            ].join(' · '),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (s['is_class_teacher'] == true) const StatusChip(label: 'Class teacher', color: AppColors.emerald),
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

class SectionStudentsScreen extends StatelessWidget {
  const SectionStudentsScreen({super.key, required this.sectionId, required this.title});

  final int sectionId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: title,
      body: AsyncView<dynamic>(
        loader: () => api.get('/teacher/sections/$sectionId/students'),
        builder: (context, data, reload) {
          final students = (data as List? ?? const []).cast<Map>();
          if (students.isEmpty) {
            return const EmptyView(icon: Icons.person_off_outlined, message: 'No students enrolled.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = students[i];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => StudentProfileScreen(studentId: s['id'] as int))),
                child: Row(
                  children: [
                    Avatar(name: (s['name'] ?? '').toString(), photoUrl: s['photo_url'] as String?),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((s['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text((s['admission_no'] ?? '').toString(),
                              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (s['roll_no'] != null) StatusChip(label: 'Roll ${s['roll_no']}', color: AppColors.sky),
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
