import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../push/push_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'family_home.dart';
import 'inbox_screen.dart';
import 'notices_screen.dart';
import 'profile_screen.dart';
import 'teacher_home.dart';
import 'bus/bus_crew_screens.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // send this phone's push token to the school, then open a notification tapped while closed
    PushService.instance.registerDevice();
    PushService.instance.openPending();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pages = <Widget>[
      state.isBusOnly
          ? const BusRoutesScreen(embedded: true)
          : (state.showTeacher ? const TeacherHome() : const FamilyHome()),
      const NoticesScreen(),
      const InboxScreen(),
      const ProfileScreen(),
    ];
    final items = [
      (Icons.home_rounded, 'Home', 0),
      (Icons.campaign_rounded, 'Notices', 0),
      (Icons.notifications_rounded, 'Inbox', state.unread),
      (Icons.person_rounded, 'Profile', 0),
    ];
    return Scaffold(
      backgroundColor: state.showTeacher ? AppColors.teacherGround : AppColors.ground,
      extendBody: false,
      body: DottedBackground(teacher: state.showTeacher, child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.night,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x331B1F3B), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Badge(
                          isLabelVisible: items[i].$3 > 0,
                          label: Text('${items[i].$3}'),
                          backgroundColor: AppColors.coral,
                          child: Icon(items[i].$1, color: _index == i ? AppColors.sun : const Color(0xFFC9CCE6)),
                        ),
                        const SizedBox(height: 3),
                        Text(items[i].$2,
                            style: TextStyle(
                                color: _index == i ? AppColors.sun : const Color(0xFFC9CCE6),
                                fontSize: 11.5,
                                fontWeight: _index == i ? FontWeight.w800 : FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Greeting header shared by the family and teacher home screens: a coloured, rounded panel with
/// playful shapes (indigo for families, teal for teachers).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.subtitle, this.bottom});

  final String subtitle;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final name = (state.user['name'] ?? '').toString();
    final color = state.showTeacher ? AppColors.teacher : AppColors.indigo;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            bottom: -70,
            child: Container(
                width: 140, height: 140, decoration: BoxDecoration(color: AppColors.sun.withAlpha(215), shape: BoxShape.circle)),
          ),
          Positioned(
            right: 96,
            bottom: 16,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                  width: 26, height: 26, decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(9))),
            ),
          ),
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(30), width: 14)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (state.school['name'] ?? '').toString().toUpperCase(),
                        style: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.canSwitchMode)
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          foregroundColor: Colors.white,
                          selectedBackgroundColor: Colors.white,
                          selectedForegroundColor: color,
                          side: BorderSide(color: Colors.white.withAlpha(60)),
                          visualDensity: VisualDensity.compact,
                        ),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'family', label: Text('Family')),
                          ButtonSegment(value: 'teacher', label: Text('Teacher')),
                        ],
                        selected: {state.mode},
                        onSelectionChanged: (value) => state.setMode(value.first),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(greeting, style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14, fontWeight: FontWeight.w600)),
                Text(name, style: headingStyle(size: 28, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(215), fontWeight: FontWeight.w600)),
                if (bottom != null) ...[const SizedBox(height: 16), bottom!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature shortcut on the home screens: a tinted rounded icon with its label underneath.
class FeatureTile extends StatelessWidget {
  const FeatureTile({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Color.alphaBlend(color.withAlpha(36), Colors.white),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: color.withAlpha(40), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(height: 7),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 12.5, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 700 ? 6 : (width > 500 ? 5 : 4);
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 6,
      childAspectRatio: 0.74,
      children: tiles,
    );
  }
}

/// Small metric card (attendance %, fee balance ...): tinted with the metric's colour.
class StatCard extends StatelessWidget {
  const StatCard(
      {super.key, required this.label, required this.value, required this.icon, required this.color, this.sub, this.onTap});

  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Color.alphaBlend(color.withAlpha(30), Colors.white);
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(60), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 12.5))),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const Spacer(),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: headingStyle(size: 26, color: color)),
              if (sub != null)
                Text(sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
