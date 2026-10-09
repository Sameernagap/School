import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'Fees',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/fees'),
        builder: (context, data, reload) {
          final plans = (data as List? ?? const []).cast<Map>();
          if (plans.isEmpty) {
            return const EmptyView(
                icon: Icons.receipt_long, message: 'No fee plan has been created yet.', color: AppColors.teal);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final plan in plans) ...[
                _PlanSummary(plan: plan),
                const SectionTitle('Installments'),
                for (final inst in (plan['installments'] as List? ?? const []).cast<Map>())
                  _InstallmentCard(studentId: studentId, inst: inst, onReturn: reload),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final Map plan;

  @override
  Widget build(BuildContext context) {
    final paidPercent = ((plan['paid_percent'] ?? 0) as num).toDouble();
    final overdue = ((plan['overdue']?['amount'] ?? 0) as num) > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF115E59)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${nameOf(plan['academic_year'])} · ${plan['structure'] ?? ''}',
              style: const TextStyle(color: Color(0xFFCCFBF1), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Balance to pay', style: TextStyle(color: Colors.white70)),
          Text(fmtMoney(plan['balance']),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (paidPercent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _kv('Total', fmtMoney(plan['net'])),
              _kv('Paid', fmtMoney(plan['paid'])),
              if (overdue) _kv('Overdue', fmtMoney(plan['overdue'])),
            ],
          ),
          if ((plan['concessions'] as List? ?? const []).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Concession: ${(plan['concessions'] as List).join(', ')}',
                style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      );
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.studentId, required this.inst, required this.onReturn});

  final int studentId;
  final Map inst;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final overdue = inst['overdue'] == true;
    final heads = (inst['heads'] as List? ?? const []).cast<Map>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((inst['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        overdue ? 'Overdue by ${inst['days_overdue']} days' : 'Due ${fmtDate(inst['due_date'])}',
                        style: TextStyle(color: overdue ? AppColors.rose : AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtMoney(inst['amount']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    StatusChip(
                      label: overdue ? 'Overdue' : (inst['state_label'] ?? '').toString(),
                      status: overdue ? 'absent' : inst['state']?.toString(),
                    ),
                  ],
                ),
              ],
            ),
            if (heads.isNotEmpty) ...[
              const Divider(height: 22),
              for (final h in heads)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text((h['name'] ?? '').toString(), style: const TextStyle(color: AppColors.muted))),
                      Text(fmtMoney(h['amount'])),
                    ],
                  ),
                ),
              if (((inst['concession']?['amount'] ?? 0) as num) > 0)
                Row(
                  children: [
                    const Expanded(child: Text('Concession', style: TextStyle(color: AppColors.emerald))),
                    Text('- ${fmtMoney(inst['concession'])}', style: const TextStyle(color: AppColors.emerald)),
                  ],
                ),
              if (inst['late_fee'] != null)
                Row(
                  children: [
                    const Expanded(child: Text('Late fee', style: TextStyle(color: AppColors.rose))),
                    Text(fmtMoney(inst['late_fee']), style: const TextStyle(color: AppColors.rose)),
                  ],
                ),
            ],
            if (((inst['paid']?['amount'] ?? 0) as num) > 0) ...[
              const SizedBox(height: 6),
              Text('Paid ${fmtMoney(inst['paid'])} · balance ${fmtMoney(inst['balance'])}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
            if (inst['pay_url'] != null || inst['receipt_url'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (inst['receipt_url'] != null)
                    OutlinedButton.icon(
                      onPressed: () => openRemoteFile(
                          context, inst['receipt_url'].toString(), 'Fee receipt ${inst['name']}.pdf'),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Receipt'),
                    ),
                  const Spacer(),
                  if (inst['pay_url'] != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                      onPressed: () async {
                        await openExternalUrl(context, inst['pay_url'].toString());
                        await onReturn();
                      },
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: Text('Pay ${fmtMoney(inst['balance'])}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
