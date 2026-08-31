import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/current_user_provider.dart';
import '../theme/app_theme.dart';

/// The bottom-nav shell wrapping every branch defined in app_router.dart.
///
/// Branch indices are FIXED and never change regardless of role —
/// go_router's StatefulShellRoute needs a static branch list so each
/// tab keeps its own navigation stack and IndexedStack slot stable:
///   0 = Dashboard, 1 = Feed, 2 = Materials, 3 = Polls,
///   4 = Profile,   5 = Manage, 6 = Admin
///
/// What changes per role is (a) which branches are visible at all, and
/// (b) how they're arranged:
///   - student/rep: a normal NavigationBar, Profile always last.
///   - admin: 7 flat items was cramped (labels were wrapping to two
///     lines — Material's own guidance caps a standard bottom nav at
///     5). Admin becomes a centered, elevated, notched FAB instead of
///     a 7th flat item — Flutter's built-in BottomAppBar + docked FAB
///     pattern, not a custom hack.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _dashboard = _Dest(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard');
  static const _feed = _Dest(1, Icons.campaign_outlined, Icons.campaign, 'Feed');
  static const _materials = _Dest(2, Icons.folder_outlined, Icons.folder, 'Materials');
  static const _polls = _Dest(3, Icons.poll_outlined, Icons.poll, 'Polls');
  static const _profile = _Dest(4, Icons.person_outline, Icons.person, 'Profile');
  static const _manage = _Dest(5, Icons.dashboard_customize_outlined, Icons.dashboard_customize, 'Manage');
  static const _admin = _Dest(6, Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser.maybeWhen(data: (u) => u.role, orElse: () => null);

    if (role == 'admin') {
      return _AdminShell(navigationShell: navigationShell);
    }

    final destinations = role == 'rep'
        ? const [_dashboard, _feed, _materials, _polls, _manage, _profile]
        : const [_dashboard, _feed, _materials, _polls, _profile];

    final selectedPosition = destinations.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Theme(
        // NavigationBar only exposes indicatorColor directly; icon/label
        // color swap on selection goes through the theme.
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? AppTheme.paper : AppTheme.muted,
                size: 24,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: states.contains(WidgetState.selected) ? AppTheme.paper : AppTheme.muted,
              ),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedPosition < 0 ? 0 : selectedPosition,
          onDestinationSelected: (position) => _goBranch(
            navigationShell,
            destinations[position].branchIndex,
          ),
          backgroundColor: AppTheme.paper,
          indicatorColor: AppTheme.ink,
          // Was showing all 6 labels at once, which is what caused
          // "Dashboard" to wrap — only the active tab's label competing
          // for space fixes that, and reads cleaner besides.
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.outlineIcon),
                selectedIcon: Icon(d.filledIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminShell extends StatelessWidget {
  const _AdminShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _left = [AppShell._dashboard, AppShell._feed, AppShell._materials];
  static const _right = [AppShell._polls, AppShell._manage, AppShell._profile];

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final adminSelected = currentIndex == AppShell._admin.branchIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goBranch(navigationShell, AppShell._admin.branchIndex),
        backgroundColor: AppTheme.ink,
        foregroundColor: AppTheme.paper,
        shape: CircleBorder(
          side: BorderSide(
            color: adminSelected ? AppTheme.paper : Colors.transparent,
            width: 2,
          ),
        ),
        tooltip: 'Admin',
        child: Icon(adminSelected ? AppShell._admin.filledIcon : AppShell._admin.outlineIcon),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.paper,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final d in _left)
              _BarItem(
                dest: d,
                selected: currentIndex == d.branchIndex,
                onTap: () => _goBranch(navigationShell, d.branchIndex),
              ),
            // Reserves the gap the FAB notch sits in.
            const SizedBox(width: 48),
            for (final d in _right)
              _BarItem(
                dest: d,
                selected: currentIndex == d.branchIndex,
                onTap: () => _goBranch(navigationShell, d.branchIndex),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.dest, required this.selected, required this.onTap});

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? dest.filledIcon : dest.outlineIcon,
              color: selected ? AppTheme.paper : AppTheme.muted,
              size: 22,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                dest.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.paper,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _goBranch(StatefulNavigationShell shell, int branchIndex) {
  shell.goBranch(
    branchIndex,
    // Tapping the already-selected tab pops it back to its own root
    // instead of doing nothing.
    initialLocation: branchIndex == shell.currentIndex,
  );
}

class _Dest {
  const _Dest(this.branchIndex, this.outlineIcon, this.filledIcon, this.label);

  final int branchIndex;
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
}
