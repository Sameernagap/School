import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Homework', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: AppColors.ground,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(tabs: [Tab(text: 'To do'), Tab(text: 'Done'), Tab(text: 'All')]),
        ),
        body: TabBarView(
          children: [
            _HomeworkList(studentId: studentId, status: 'pending'),
            _HomeworkList(studentId: studentId, status: 'done'),
            _HomeworkList(studentId: studentId, status: 'all'),
          ],
        ),
      ),
    );
  }
}

class _HomeworkList extends StatelessWidget {
  const _HomeworkList({required this.studentId, required this.status});

  final int studentId;
  final String status;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return AsyncView<dynamic>(
      loader: () => api.get('/students/$studentId/homework', query: {'status': status, 'limit': '50'}),
      builder: (context, data, reload) {
        final items = (data['items'] as List? ?? const []).cast<Map>();
        if (items.isEmpty) {
          return EmptyView(
            icon: Icons.task_alt,
            color: AppColors.pink,
            message: status == 'pending' ? 'No homework pending. Well done!' : 'Nothing here yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final hw = items[i];
            final overdue = hw['overdue'] == true;
            return AppCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HomeworkDetailScreen(studentId: studentId, homeworkId: hw['id'] as int)),
              ),
              child: Row(
                children: [
                  const IconTile(icon: Icons.edit_note_rounded, color: AppColors.pink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nameOf(hw['subject']),
                            style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.w700, fontSize: 12)),
                        Text((hw['title'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('Due ${fmtDate(hw['due_date'])}',
                            style: TextStyle(
                                color: overdue ? AppColors.rose : AppColors.muted,
                                fontWeight: overdue ? FontWeight.w700 : FontWeight.w500)),
                      ],
                    ),
                  ),
                  StatusChip(label: (hw['status_label'] ?? '').toString(), status: hw['status']?.toString()),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class HomeworkDetailScreen extends StatelessWidget {
  const HomeworkDetailScreen({super.key, required this.studentId, required this.homeworkId});

  final int studentId;
  final int homeworkId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Homework',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/homework/$homeworkId'),
        builder: (context, hw, reload) {
          final attachments = (hw['attachments'] as List? ?? const []).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                color: AppColors.pink,
                icon: Icons.edit_note_rounded,
                title: (hw['title'] ?? '').toString(),
                subtitle: '${nameOf(hw['subject'])} · ${nameOf(hw['teacher'])}',
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Given on', fmtDate(hw['assign_date'])),
                    InfoRow('Due date', fmtDate(hw['due_date'])),
                    InfoRow('Status', (hw['status_label'] ?? '').toString()),
                    if (hw['grade'] != null) InfoRow('Grade', hw['grade'].toString()),
                    if (hw['remark'] != null) InfoRow("Teacher's remark", hw['remark'].toString()),
                  ],
                ),
              ),
              const SectionTitle('What to do'),
              AppCard(
                child: Text(
                  (hw['description_text'] ?? '').toString().isEmpty
                      ? 'No description.'
                      : hw['description_text'].toString(),
                  style: const TextStyle(height: 1.5),
                ),
              ),
              if (attachments.isNotEmpty) ...[
                const SectionTitle('Attachments'),
                for (final a in attachments) AttachmentTile(attachment: a),
              ],
            ],
          );
        },
      ),
    );
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment});

  final Map attachment;

  @override
  Widget build(BuildContext context) {
    final name = (attachment['name'] ?? 'file').toString();
    final isPdf = name.toLowerCase().endsWith('.pdf');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => openRemoteFile(context, attachment['url'].toString(), name),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconTile(icon: isPdf ? Icons.picture_as_pdf : Icons.attach_file, color: AppColors.slate, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.download_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
