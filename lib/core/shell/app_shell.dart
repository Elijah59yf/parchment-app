import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/current_user_provider.dart';
import '../theme/app_theme.dart';

/// The bottom-nav shell wrapping every branch defined in app_router.dart.
///
/// Branch order is FIXED (dashboard, feed, materials, polls, profile,
/// manage, admin) and never changes regardless of role — go_router's
/// StatefulShellRoute needs a static branch list so each tab's own
/// navigation stack and IndexedStack slot stay stable. What changes per
/// role is only which of those branches show up as a visible nav item.
///
/// Because student ⊂ rep ⊂ admin (each role's tabs are a superset of
/// the one below), manage/admin just get appended at the end and
/// hidden for roles that don't have them — no reordering needed.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _allDestinations = [
    _ShellDestination(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _ShellDestination(1, Icons.campaign_outlined, Icons.campaign, 'Feed'),
    _ShellDestination(2, Icons.folder_outlined, Icons.folder, 'Materials'),
    _ShellDestination(3, Icons.poll_outlined, Icons.poll, 'Polls'),
    _ShellDestination(4, Icons.person_outline, Icons.person, 'Profile'),
    _ShellDestination(5, Icons.dashboard_customize_outlined, Icons.dashboard_customize, 'Manage'),
    _ShellDestination(6, Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin'),
  ];

  List<_ShellDestination> _destinationsForRole(String? role) {
    final base = _allDestinations.sublist(0, 5); // dashboard..profile
    if (role == 'rep') return [...base, _allDestinations[5]];
    if (role == 'admin') return [...base, _allDestinations[5], _allDestinations[6]];
    return base; // student
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser.maybeWhen(data: (u) => u.role, orElse: () => null);
    final destinations = _destinationsForRole(role);

    // navigationShell.currentIndex is a branch index (0-6); map it to a
    // position within the currently-visible destinations list. Falls
    // back to 0 if the active branch isn't visible for this role yet
    // (e.g. briefly while currentUser is still loading on cold start).
    final selectedPosition = destinations.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedPosition < 0 ? 0 : selectedPosition,
        onDestinationSelected: (position) {
          navigationShell.goBranch(
            destinations[position].branchIndex,
            // Tapping the already-selected tab pops it back to its
            // own root instead of doing nothing.
            initialLocation:
                destinations[position].branchIndex == navigationShell.currentIndex,
          );
        },
        backgroundColor: AppTheme.paper,
        indicatorColor: AppTheme.surface,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.outlineIcon),
              selectedIcon: Icon(d.filledIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(
    this.branchIndex,
    this.outlineIcon,
    this.filledIcon,
    this.label,
  );

  final int branchIndex;
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
}
