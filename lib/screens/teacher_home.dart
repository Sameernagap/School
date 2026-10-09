import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'student/timetable_screen.dart';
import 'teacher/attendance_take_screen.dart';
import 'teacher/homework_teacher_screen.dart';
import 'teacher/leave_approvals_screen.dart';
import 'teacher/marks_screen.dart';
import 'teacher/sections_screen.dart';
import 'teacher/send_notice_screen.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final state = context.read<AppState>();
    final api = state.api;
    Future<dynamic> safe(Future<dynamic> f) async {
      try {
        return await f;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(api.get('/teacher/sections')),
      state.hasFeature('attendance') ? safe(api.get('/teacher/attendance')) : Future.value(null),
      state.hasFeature('attendance') ? safe(api.get('/teacher/leaves', query: {'limit': '1'})) : Future.value(null),
      state.hasFeature('exams') ? safe(api.get('/teacher/marksheets', query: {'limit': '1'})) : Future.value(null),
    ]);
    return {'sections': results[0], 'attendance': results[1], 'leaves': results[2], 'marks': results[3]};
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  void _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final teacher = state.me['teacher'] is Map ? state.me['teacher'] as Map : const {};
    final classTeacherOf = (teacher['class_teacher_of'] as List? ?? const []).cast<Map>();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HomeHeader(
              subtitle: classTeacherOf.isNotEmpty
                  ? 'Class teacher of ${classTeacherOf.map((s) => s['name']).join(', ')}'
                  : '${teacher['section_count'] ?? 0} sections',
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 132, child: Center(child: CircularProgressIndicator()));
                }
                final data = snapshot.data!;
                final cards = <Widget>[];
                final attendance = data['attendance'];
                if (attendance is Map) {
                  final missing = (attendance['not_taken'] as List? ?? const []).length;
                  cards.add(StatCard(
                    label: 'Attendance today',
                    value: missing > 0 ? '$missing to take' : 'Done',
                    sub: missing > 0 ? 'Tap to take attendance' : 'All your classes marked',
                    icon: Icons.fact_check_rounded,
                    color: missing > 0 ? AppColors.amber : AppColors.emerald,
                    onTap: () => _open(const AttendanceTakeScreen()),
                  ));
                }
                final leaves = data['leaves'];
                if (leaves is Map) {
                  cards.add(StatCard(
                    label: 'Leave requests',
                    value: '${leaves['total'] ?? 0}',
                    sub: 'Waiting for you',
                    icon: Icons.event_busy_rounded,
                    color: AppColors.sky,
                    onTap: () => _open(const LeaveApprovalsScreen()),
                  ));
                }
                final marks = data['marks'];
                if (marks is Map) {
                  cards.add(StatCard(
                    label: 'Marks to enter',
                    value: '${marks['total'] ?? 0}',
                    sub: 'Marksheets open',
                    icon: Icons.assignment_rounded,
                    color: AppColors.purple,
                    onTap: () => _open(const MarksheetsScreen()),
                  ));
                }
                final sections = data['sections'];
                if (sections is List) {
                  final students = sections.fold<int>(0, (sum, s) => sum + ((s as Map)['student_count'] ?? 0) as int);
                  cards.add(StatCard(
                    label: 'My classes',
                    value: '${sections.length}',
                    sub: '$students students',
                    icon: Icons.groups_rounded,
                    color: AppColors.indigo,
                    onTap: () => _open(const SectionsScreen()),
                  ));
                }
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Classroom'),
                  FeatureGrid(tiles: [
                    if (state.hasFeature('attendance'))
                      FeatureTile(
                          icon: Icons.fact_check_rounded,
                          label: 'Take Attendance',
                          color: AppColors.emerald,
                          onTap: () => _open(const AttendanceTakeScreen())),
                    if (state.hasFeature('homework'))
                      FeatureTile(
                          icon: Icons.edit_note_rounded,
                          label: 'Homework',
                          color: AppColors.pink,
                          onTap: () => _open(const TeacherHomeworkScreen())),
                    if (state.hasFeature('exams'))
                      FeatureTile(
                          icon: Icons.assignment_rounded,
                          label: 'Enter Marks',
                          color: AppColors.purple,
                          onTap: () => _open(const MarksheetsScreen())),
                    if (state.hasFeature('attendance'))
                      FeatureTile(
                          icon: Icons.event_busy_rounded,
                          label: 'Leave Requests',
                          color: AppColors.sky,
                          onTap: () => _open(const LeaveApprovalsScreen())),
                    if (state.hasFeature('timetable'))
                      FeatureTile(
                          icon: Icons.schedule_rounded,
                          label: 'My Timetable',
                          color: AppColors.orange,
                          onTap: () => _open(const TimetableScreen(
                              path: '/teacher/timetable', title: 'My timetable', showSection: true))),
                    FeatureTile(
                        icon: Icons.groups_rounded,
                        label: 'My Classes',
                        color: AppColors.indigo,
                        onTap: () => _open(const SectionsScreen())),
                    if (state.hasFeature('notices'))
                      FeatureTile(
                          icon: Icons.campaign_rounded,
                          label: 'Send Notice',
                          color: AppColors.amber,
                          onTap: () => _open(const SendNoticeScreen())),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
