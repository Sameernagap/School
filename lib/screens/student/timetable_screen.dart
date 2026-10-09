import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

const _subjectColors = [
  AppColors.indigo, AppColors.emerald, AppColors.orange, AppColors.pink, AppColors.sky,
  AppColors.purple, AppColors.teal, AppColors.amber, AppColors.lime, AppColors.rose,
];

/// Weekly timetable. [path] = /students/{id}/timetable or /teacher/timetable.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.path, required this.title, this.showSection = false});

  final String path;
  final String title;
  final bool showSection;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: title,
      body: AsyncView<dynamic>(
        loader: () => api.get(path),
        builder: (context, data, reload) {
          final days = (data['days'] as List? ?? const []).cast<Map>();
          if (days.isEmpty) {
            return const EmptyView(
                icon: Icons.schedule, message: 'The timetable has not been published yet.', color: AppColors.orange);
          }
          final today = DateTime.now().weekday - 1;
          var initial = days.indexWhere((d) => d['day'] == today);
          if (initial < 0) initial = 0;
          return DefaultTabController(
            length: days.length,
            initialIndex: initial,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: [for (final d in days) Tab(text: (d['day_label'] ?? '').toString())],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final d in days)
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final slot in (d['slots'] as List? ?? const []).cast<Map>()) _slot(slot),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _slot(Map slot) {
    final subjectId = (slot['subject'] is Map ? slot['subject']['id'] : 0) as int;
    final color = _subjectColors[subjectId % _subjectColors.length];
    final details = [
      if (showSection) nameOf(slot['section']) else nameOf(slot['teacher']),
      if (slot['room'] != null) 'Room ${slot['room']}',
    ].where((t) => t.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text((slot['start'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text((slot['end'] ?? '').toString(), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(nameOf(slot['subject']),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                      if (details.isNotEmpty)
                        Text(details, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Text(nameOf(slot['period']), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
