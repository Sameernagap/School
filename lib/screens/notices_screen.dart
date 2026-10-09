import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'student/homework_screen.dart' show AttachmentTile;

const _typeColors = {
  'general': AppColors.indigo,
  'event': AppColors.emerald,
  'holiday': AppColors.orange,
  'exam': AppColors.purple,
  'fee': AppColors.teal,
  'urgent': AppColors.rose,
};

const _typeIcons = {
  'general': Icons.campaign_rounded,
  'event': Icons.celebration_rounded,
  'holiday': Icons.beach_access_rounded,
  'exam': Icons.emoji_events_rounded,
  'fee': Icons.currency_rupee_rounded,
  'urgent': Icons.priority_high_rounded,
};

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.hasFeature('notices')) {
      return const PageScaffold(
          title: 'Notices', body: EmptyView(icon: Icons.campaign_outlined, message: 'Notices are not enabled.'));
    }
    return PageScaffold(
      title: 'Notices',
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _filter(null, 'All'),
                _filter('event', 'Events'),
                _filter('holiday', 'Holidays'),
                _filter('exam', 'Exams'),
                _filter('fee', 'Fees'),
                _filter('urgent', 'Urgent'),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<dynamic>(
              reloadKey: _type,
              loader: () => state.api.get('/notices', query: {'limit': '50', if (_type != null) 'type': _type!}),
              builder: (context, data, reload) {
                final items = (data['items'] as List? ?? const []).cast<Map>();
                if (items.isEmpty) {
                  return const EmptyView(icon: Icons.campaign_outlined, message: 'No notices for now.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => NoticeCard(notice: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filter(String? value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: _type == value, onSelected: (_) => setState(() => _type = value)),
      );
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice});

  final Map notice;

  @override
  Widget build(BuildContext context) {
    final type = (notice['type'] ?? 'general').toString();
    final color = _typeColors[type] ?? AppColors.indigo;
    return AppCard(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => NoticeDetailScreen(noticeId: notice['id'] as int))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: _typeIcons[type] ?? Icons.campaign_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (notice['pinned'] == true)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin, size: 15, color: AppColors.amber),
                      ),
                    Expanded(
                      child: Text((notice['title'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text((notice['summary'] ?? '').toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip(label: (notice['type_label'] ?? type).toString(), color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notice['event_date'] != null
                            ? 'On ${fmtDate(notice['event_date'])}'
                            : fmtDateTime(notice['published_at']),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                    if ((notice['attachment_count'] ?? 0) as int > 0)
                      const Icon(Icons.attach_file, size: 16, color: AppColors.muted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.noticeId});

  final int noticeId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Notice',
      body: AsyncView<dynamic>(
        loader: () => api.get('/notices/$noticeId'),
        builder: (context, n, reload) {
          final type = (n['type'] ?? 'general').toString();
          final color = _typeColors[type] ?? AppColors.indigo;
          final attachments = (n['attachments'] as List? ?? const []).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                color: color,
                icon: _typeIcons[type],
                title: (n['title'] ?? '').toString(),
                subtitle: '${n['author'] ?? ''} · ${fmtDateTime(n['published_at'])}',
              ),
              if (n['event_date'] != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.event, color: color),
                      const SizedBox(width: 10),
                      Text('Date: ${fmtDate(n['event_date'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AppCard(child: Text((n['body_text'] ?? '').toString(), style: const TextStyle(height: 1.55, fontSize: 15))),
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
