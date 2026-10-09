import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'student/attendance_screen.dart';
import 'student/exams_screen.dart';
import 'student/fees_screen.dart';
import 'student/homework_screen.dart';
import 'student/leaves_screen.dart';
import 'student/library_screen.dart';
import 'student/student_profile_screen.dart';
import 'student/timetable_screen.dart';
import 'student/transport_screen.dart';

/// Home for parents and students: child switcher, key numbers and feature tiles.
class FamilyHome extends StatelessWidget {
  const FamilyHome({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final student = state.selectedStudent;
    if (student == null) {
      return Scaffold(
        body: Column(
          children: [
            const HomeHeader(subtitle: 'No student is linked to your account yet.'),
            const Expanded(
              child: EmptyView(
                icon: Icons.child_care,
                message: 'Ask the school office to link your children to your login.',
              ),
            ),
          ],
        ),
      );
    }
    final id = student['id'] as int;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => state.refreshMe(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HomeHeader(
              subtitle: state.isParent ? "Here is your child's day at school" : 'Here is your day at school',
              bottom: _StudentSwitcher(state: state),
            ),
            if (state.sessionMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppCard(
                  color: AppColors.soft(AppColors.amber),
                  child: Text(state.sessionMessage!, style: const TextStyle(color: AppColors.amber)),
                ),
              ),
            _Highlights(studentId: id, key: ValueKey('hl-$id')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Explore'),
                  FeatureGrid(tiles: _tiles(context, state, id)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tiles(BuildContext context, AppState state, int id) {
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return [
      if (state.hasFeature('attendance'))
        FeatureTile(
            icon: Icons.fact_check_rounded,
            label: 'Attendance',
            color: AppColors.emerald,
            onTap: () => open(AttendanceScreen(studentId: id))),
      if (state.hasFeature('timetable'))
        FeatureTile(
            icon: Icons.schedule_rounded,
            label: 'Timetable',
            color: AppColors.orange,
            onTap: () => open(TimetableScreen(path: '/students/$id/timetable', title: 'Timetable'))),
      if (state.hasFeature('homework'))
        FeatureTile(
            icon: Icons.edit_note_rounded,
            label: 'Homework',
            color: AppColors.pink,
            onTap: () => open(HomeworkScreen(studentId: id))),
      if (state.hasFeature('fees'))
        FeatureTile(
            icon: Icons.currency_rupee_rounded, label: 'Fees', color: AppColors.teal, onTap: () => open(FeesScreen(studentId: id))),
      if (state.hasFeature('exams'))
        FeatureTile(
            icon: Icons.emoji_events_rounded,
            label: 'Exams & Results',
            color: AppColors.purple,
            onTap: () => open(ExamsScreen(studentId: id))),
      if (state.hasFeature('attendance'))
        FeatureTile(
            icon: Icons.event_busy_rounded, label: 'Leave', color: AppColors.sky, onTap: () => open(LeavesScreen(studentId: id))),
      if (state.hasFeature('transport'))
        FeatureTile(
            icon: Icons.directions_bus_rounded,
            label: 'School Bus',
            color: AppColors.lime,
            onTap: () => open(TransportScreen(studentId: id))),
      if (state.hasFeature('library'))
        FeatureTile(
            icon: Icons.menu_book_rounded, label: 'Library', color: AppColors.brown, onTap: () => open(LibraryScreen(studentId: id))),
      FeatureTile(
          icon: Icons.badge_rounded, label: 'Profile', color: AppColors.indigo, onTap: () => open(StudentProfileScreen(studentId: id))),
    ];
  }
}

class _StudentSwitcher extends StatelessWidget {
  const _StudentSwitcher({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final students = state.students;
    final selected = state.selectedStudent;
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in students)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => state.selectStudent(s['id'] as int),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: s['id'] == selected?['id'] ? Colors.white : Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Avatar(name: (s['name'] ?? '').toString(), photoUrl: s['photo_url'] as String?, radius: 18),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((s['name'] ?? '').toString(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: s['id'] == selected?['id'] ? AppColors.ink : Colors.white)),
                          Text(nameOf(s['section']).isNotEmpty ? nameOf(s['section']) : nameOf(s['class']),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: s['id'] == selected?['id'] ? AppColors.muted : const Color(0xFFC7C3F0))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Attendance %, fee balance, next exam, homework due — loaded in parallel.
class _Highlights extends StatefulWidget {
  const _Highlights({super.key, required this.studentId});

  final int studentId;

  @override
  State<_Highlights> createState() => _HighlightsState();
}

class _HighlightsState extends State<_Highlights> {
  late Future<Map<String, dynamic>> _future;

  int get studentId => widget.studentId;

  @override
  void initState() {
    super.initState();
    _future = _load(context.read<AppState>());
  }

  Future<Map<String, dynamic>> _load(AppState state) async {
    final api = state.api;
    Future<dynamic> safe(Future<dynamic> f) async {
      try {
        return await f;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(api.get('/students/$studentId')),
      state.hasFeature('fees') ? safe(api.get('/students/$studentId/fees')) : Future.value(null),
      state.hasFeature('exams') ? safe(api.get('/students/$studentId/exams')) : Future.value(null),
      state.hasFeature('homework')
          ? safe(api.get('/students/$studentId/homework', query: {'status': 'pending', 'limit': '1'}))
          : Future.value(null),
    ]);
    return {'profile': results[0], 'fees': results[1], 'exams': results[2], 'homework': results[3]};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 132, child: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        final cards = <Widget>[];
        final profile = data['profile'];
        if (profile is Map && profile['attendance_rate'] != null) {
          cards.add(StatCard(
            label: 'Attendance',
            value: '${fmtNum(profile['attendance_rate'])}%',
            sub: 'This academic year',
            icon: Icons.fact_check_rounded,
            color: AppColors.emerald,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => AttendanceScreen(studentId: studentId))),
          ));
        }
        final fees = data['fees'];
        if (fees is List && fees.isNotEmpty) {
          final plan = fees.first as Map;
          final overdue = (plan['overdue']?['amount'] ?? 0) as num;
          cards.add(StatCard(
            label: 'Fee balance',
            value: fmtMoney(plan['balance']),
            sub: overdue > 0 ? '${fmtMoney(plan['overdue'])} overdue' : '${fmtNum(plan['paid_percent'])}% paid',
            icon: Icons.account_balance_wallet_rounded,
            color: overdue > 0 ? AppColors.rose : AppColors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeesScreen(studentId: studentId))),
          ));
        }
        final homework = data['homework'];
        if (homework is Map) {
          cards.add(StatCard(
            label: 'Homework due',
            value: '${homework['total'] ?? 0}',
            sub: 'Pending',
            icon: Icons.edit_note_rounded,
            color: AppColors.pink,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HomeworkScreen(studentId: studentId))),
          ));
        }
        final exams = data['exams'];
        if (exams is Map) {
          final upcoming = exams['upcoming'] as List? ?? const [];
          final results = exams['results'] as List? ?? const [];
          if (upcoming.isNotEmpty) {
            final next = upcoming.first as Map;
            cards.add(StatCard(
              label: 'Next exam',
              value: fmtDate(next['date'], year: false),
              sub: '${nameOf(next['subject'])} · ${nameOf(next['exam'])}',
              icon: Icons.event_note_rounded,
              color: AppColors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamsScreen(studentId: studentId))),
            ));
          } else if (results.isNotEmpty) {
            final last = results.first as Map;
            cards.add(StatCard(
              label: 'Last result',
              value: '${fmtNum(last['percentage'])}%',
              sub: '${nameOf(last['exam'])} · ${last['grade'] ?? ''}',
              icon: Icons.emoji_events_rounded,
              color: AppColors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamsScreen(studentId: studentId))),
            ));
          }
        }
        if (cards.isEmpty) return const SizedBox(height: 8);
        return SizedBox(
          height: 132,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => cards[i],
          ),
        );
      },
    );
  }
}
