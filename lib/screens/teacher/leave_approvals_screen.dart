import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Leave requests',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: const Text('Show all'),
            selected: _all,
            onSelected: (v) => setState(() => _all = v),
          ),
        ),
      ],
      body: AsyncView<dynamic>(
        reloadKey: _all,
        loader: () => api.get('/teacher/leaves', query: {'state': _all ? 'all' : 'to_approve', 'limit': '50'}),
        builder: (context, data, reload) {
          final items = (data['items'] as List? ?? const []).cast<Map>();
          if (items.isEmpty) {
            return const EmptyView(
                icon: Icons.event_available, message: 'No leave requests waiting.', color: AppColors.sky);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final leave = items[i];
              final student = leave['student'] as Map;
              Future<void> decide(String decision) async {
                final ok = await runAction(context, () async {
                  await api.post('/teacher/leaves/${leave['id']}/$decision');
                }, success: decision == 'approve' ? 'Leave approved' : 'Leave rejected');
                if (ok) reload();
              }

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Avatar(name: (student['name'] ?? '').toString(), photoUrl: student['photo_url'] as String?),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((student['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${nameOf(student['section'])} · by ${leave['requested_by']}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        StatusChip(label: (leave['state'] ?? '').toString().replaceAll('_', ' '),
                            status: leave['state']?.toString()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${fmtDate(leave['date_from'], year: false)} → ${fmtDate(leave['date_to'])} · ${leave['days']} day(s)',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text((leave['reason'] ?? '').toString()),
                    if (leave['state'] == 'to_approve') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
                              onPressed: () => decide('reject'),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                              onPressed: () => decide('approve'),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
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
