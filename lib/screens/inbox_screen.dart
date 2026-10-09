import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'notices_screen.dart';
import 'student/attendance_screen.dart';
import 'student/exams_screen.dart';
import 'student/fees_screen.dart';
import 'student/homework_screen.dart';
import 'student/leaves_screen.dart';

const categoryColors = {
  'notice': AppColors.amber,
  'homework': AppColors.pink,
  'attendance': AppColors.emerald,
  'leave': AppColors.sky,
  'exam': AppColors.purple,
  'fees': AppColors.teal,
  'general': AppColors.indigo,
};

const categoryIcons = {
  'notice': Icons.campaign_rounded,
  'homework': Icons.edit_note_rounded,
  'attendance': Icons.fact_check_rounded,
  'leave': Icons.event_busy_rounded,
  'exam': Icons.emoji_events_rounded,
  'fees': Icons.currency_rupee_rounded,
  'general': Icons.notifications_rounded,
};

/// Opens the screen a notification is about (also used when a push is tapped).
void openNotificationTarget(BuildContext context, Map n) {
  final studentId = n['student_id'] is int ? n['student_id'] as int : null;
  final resId = n['res_id'] is int ? n['res_id'] as int : null;
  Widget? page;
  switch (n['category']) {
    case 'notice':
      if (resId != null) page = NoticeDetailScreen(noticeId: resId);
      break;
    case 'homework':
      if (studentId != null && resId != null) page = HomeworkDetailScreen(studentId: studentId, homeworkId: resId);
      break;
    case 'attendance':
      if (studentId != null) page = AttendanceScreen(studentId: studentId);
      break;
    case 'leave':
      if (studentId != null) page = LeavesScreen(studentId: studentId);
      break;
    case 'exam':
      if (studentId != null && resId != null) page = ResultScreen(studentId: studentId, resultId: resId);
      break;
    case 'fees':
      if (studentId != null) page = FeesScreen(studentId: studentId);
      break;
  }
  if (page != null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _version = 0;

  Future<void> _markAll(AppState state) async {
    final ok = await runAction(context, () async {
      await state.api.post('/notifications/read', {'all': true});
    });
    if (ok) {
      state.setUnread(0);
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return PageScaffold(
      title: 'Inbox',
      actions: [
        TextButton.icon(
          onPressed: () => _markAll(state),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Read all'),
        ),
      ],
      body: AsyncView<dynamic>(
        reloadKey: _version,
        loader: () async {
          final data = await state.api.get('/notifications', query: {'limit': '50'});
          state.setUnread((data['unread'] ?? 0) as int);
          return data;
        },
        builder: (context, data, reload) {
          final items = (data['items'] as List? ?? const []).cast<Map>();
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.notifications_none, message: "You're all caught up.");
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              final category = (n['category'] ?? 'general').toString();
              final color = categoryColors[category] ?? AppColors.indigo;
              final unread = n['is_read'] != true;
              return AppCard(
                color: unread ? const Color(0xFFF5F3FF) : Colors.white,
                onTap: () async {
                  if (unread) {
                    try {
                      await state.api.post('/notifications/read', {'ids': [n['id']]});
                      state.setUnread(state.unread > 0 ? state.unread - 1 : 0);
                    } catch (_) {}
                  }
                  if (context.mounted) openNotificationTarget(context, n);
                  reload();
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(icon: categoryIcons[category] ?? Icons.notifications, color: color, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((n['title'] ?? '').toString(),
                              style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                          if ((n['body'] ?? '').toString().isNotEmpty)
                            Text(n['body'].toString(), style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 4),
                          Text(fmtDateTime(n['date']), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(color: AppColors.indigo, shape: BoxShape.circle),
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
