import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Library',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/library'),
        builder: (context, data, reload) {
          final current = (data['current'] as List? ?? const []).cast<Map>();
          final history = (data['history'] as List? ?? const []).cast<Map>();
          final fines = (data['unpaid_fines'] ?? 0) as num;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                color: AppColors.brown,
                icon: Icons.menu_book_rounded,
                title: '${current.length} book(s) issued',
                subtitle: fines > 0 ? 'Unpaid fines: ${groupThousands(fines)}' : 'No fines due',
              ),
              const SectionTitle('With the student now'),
              if (current.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No books issued.', style: TextStyle(color: AppColors.muted))),
              for (final issue in current) _issue(issue, true),
              if (history.isNotEmpty) ...[
                const SectionTitle('Returned'),
                for (final issue in history) _issue(issue, false),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _issue(Map issue, bool current) {
    final book = Map<String, dynamic>.from(issue['book'] as Map);
    final overdue = issue['overdue'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            const IconTile(icon: Icons.menu_book_rounded, color: AppColors.brown),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((book['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (book['author'] != null)
                    Text(book['author'].toString(), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  Text(
                    current
                        ? (overdue
                            ? 'Overdue by ${issue['overdue_days']} days'
                            : 'Return by ${fmtDate(issue['due_date'])}')
                        : 'Returned ${fmtDate(issue['return_date'])}',
                    style: TextStyle(
                        color: overdue ? AppColors.rose : AppColors.muted,
                        fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
            if (issue['fine'] != null)
              StatusChip(
                  label: 'Fine ${fmtMoney(issue['fine'])}${issue['fine_paid'] == true ? ' paid' : ''}',
                  status: issue['fine_paid'] == true ? 'paid' : 'absent')
            else if (overdue)
              const StatusChip(label: 'Overdue', status: 'absent'),
          ],
        ),
      ),
    );
  }
}
