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
import 'teacher/qr_attendance_screen.dart';
import 'staff/staff_attendance_screen.dart';
import 'staff/staff_leave_screen.dart';
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
      backgroundColor: Colors.transparent,
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
                Widget? todayCard;
                if (attendance is Map && classTeacherOf.isNotEmpty) {
                  final missing = (attendance['not_taken'] as List? ?? const []).length;
                  todayCard = _TodayAttendanceCard(
                    missing: missing,
                    classes: classTeacherOf.map((s) => s['name']).join(', '),
                    canScan: state.hasFeature('qr_attendance'),
                    onScan: () => _open(const QrAttendanceScreen()),
                    onList: () => _open(const AttendanceTakeScreen()),
                  );
                } else if (state.hasFeature('attendance') && attendance == null && classTeacherOf.isNotEmpty) {
                  todayCard = const _ServerUpdateCard();
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (todayCard != null) Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: todayCard),
                    if (cards.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: Text('Waiting for you', style: headingStyle(size: 19)),
                      ),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: cards.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => cards[i],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                    if (state.hasFeature('attendance') && state.hasFeature('qr_attendance'))
                      FeatureTile(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan ID Cards',
                          color: AppColors.teal,
                          onTap: () => _open(const QrAttendanceScreen())),
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
                    if (state.hasFeature('staff'))
                      FeatureTile(
                          icon: Icons.badge_rounded,
                          label: 'My Attendance',
                          color: AppColors.cyan,
                          onTap: () => _open(const StaffAttendanceScreen())),
                    if (state.hasFeature('staff'))
                      FeatureTile(
                          icon: Icons.beach_access_rounded,
                          label: 'My Leave',
                          color: AppColors.violet,
                          onTap: () => _open(const StaffLeaveScreen())),
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


/// "Today's attendance" call to action for class teachers.
class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard(
      {required this.missing, required this.classes, required this.canScan, required this.onScan, required this.onList});

  final int missing;
  final String classes;
  final bool canScan;
  final VoidCallback onScan;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final done = missing == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x161B1F3B), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's attendance", style: headingStyle(size: 18)),
                    Text(classes, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: done ? const Color(0xFFDDF6E8) : const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(done ? 'Done' : 'Not taken',
                    style: TextStyle(
                        color: done ? const Color(0xFF0F6B3E) : const Color(0xFF8A5A00),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5)),
              ),
            ],
          ),
          if (!done) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canScan) ...[
                  Expanded(
                    flex: 7,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sun,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: onScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan ID cards'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 5,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE6F4F2),
                      foregroundColor: const Color(0xFF0F5C55),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: onList,
                    child: const Text('Mark by list'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the attendance service answers with an error (usually: Odoo module not upgraded).
class _ServerUpdateCard extends StatelessWidget {
  const _ServerUpdateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD3CB), width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB5321F)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Attendance could not be loaded from the school server. Ask the administrator to upgrade the school modules.',
              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7A2418)),
            ),
          ),
        ],
      ),
    );
  }
}
