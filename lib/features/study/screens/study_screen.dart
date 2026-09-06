import 'package:flutter/material.dart';

import '../../../core/widgets/coming_soon_screen.dart';
import '../../courses/screens/courses_screen.dart';

/// The Study tab (replaces the old separate Courses/Timetable/
/// Materials bottom-nav slots - see PLAN.md: three tabs would have
/// pushed student to 7 icons and rep to 8 in a bar that Material's own
/// guidance caps at 5, so they're one tab with internal sub-navigation
/// instead of three competing for bottom-bar space). Courses is real;
/// Timetable and Materials are still ComingSoonBody placeholders,
/// swapped out as each gets built - same as any other pending feature.
class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Courses'),
              Tab(text: 'Timetable'),
              Tab(text: 'Materials'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CoursesScreen(),
            ComingSoonBody(icon: Icons.schedule_outlined),
            ComingSoonBody(icon: Icons.folder_outlined),
          ],
        ),
      ),
    );
  }
}
