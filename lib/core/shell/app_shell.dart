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
/// REWRITE (2026-08-31): the previous version rendered a blank body
/// with only the nav row painted, for student/rep specifically. Root
/// cause: `_BottomBar` used a bare `Container` (no explicit height)
/// as `bottomNavigationBar`. Scaffold measures that slot with LOOSE
/// constraints, so the unbounded height propagated straight down
/// through SafeArea -> Row -> Expanded -> InkWell -> Center. `Center`
/// under unbounded constraints tries to be "as big as possible",
/// which inflated the bar to fill the whole screen and pushed the
/// body out entirely. The admin `BottomAppBar` variant was unaffected
/// because BottomAppBar enforces its own intrinsic height regardless
/// of how Scaffold measures it.
///
/// Fix: every bottom bar now sits inside a `SizedBox(height: _barHeight)`
/// BEFORE SafeArea, so every constraint from that point down is
/// bounded on both axes. No `Center`, no `Expanded` cross-axis
/// ambiguity, no intrinsic-size guessing.
///
/// Selection highlight is now a rounded rectangle (AppTheme.radius),
/// not a circle — icon-only still (every screen already shows its
/// own name in its app bar), long-press reveals the label via the
/// platform's native Tooltip.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _barHeight = 60;

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

    return Scaffold(
      body: SafeArea(
        // Only the body needs top inset; the bar handles its own
        // bottom inset below. Prevents double-padding the status bar.
        bottom: false,
        child: navigationShell,
      ),
      bottomNavigationBar: _BottomBar(
        items: destinations,
        currentBranchIndex: navigationShell.currentIndex,
        onSelect: (branchIndex) => _goBranch(navigationShell, branchIndex),
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
      body: SafeArea(
        bottom: false,
        child: navigationShell,
      ),
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
        padding: EdgeInsets.zero,
        height: AppShell._barHeight,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppShell._barHeight,
            child: Row(
              children: [
                for (final d in _left)
                  Expanded(
                    child: _BarItem(
                      dest: d,
                      selected: currentIndex == d.branchIndex,
                      onTap: () => _goBranch(navigationShell, d.branchIndex),
                    ),
                  ),
                // Reserves the gap the FAB notch sits in. Fixed width
                // is safe here: the Expanded items on either side
                // absorb any extra/short space, so the Row can never
                // overflow regardless of screen width.
                const SizedBox(width: 48),
                for (final d in _right)
                  Expanded(
                    child: _BarItem(
                      dest: d,
                      selected: currentIndex == d.branchIndex,
                      onTap: () => _goBranch(navigationShell, d.branchIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plain (non-notched) bar used for student/rep.
///
/// Height is fixed and bounded BEFORE SafeArea/Row/Expanded, which is
/// the actual fix for the blank-body bug (see class doc on AppShell).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.items,
    required this.currentBranchIndex,
    required this.onSelect,
  });

  final List<_Dest> items;
  final int currentBranchIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      // Explicit total height = bar content + the device's own home-
      // indicator inset. Nothing below this point is ever unbounded.
      height: AppShell._barHeight + bottomInset,
      // No top border — admin's BottomAppBar doesn't draw one either,
      // so this keeps all three roles visually consistent.
      color: AppTheme.paper,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppShell._barHeight,
          child: Row(
            children: [
              for (final d in items)
                Expanded(
                  child: _BarItem(
                    dest: d,
                    selected: currentBranchIndex == d.branchIndex,
                    onTap: () => onSelect(d.branchIndex),
                  ),
                ),
            ],
          ),
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
    // Icon-only, rounded-rectangle selection highlight (not a pill/
    // circle). Every dimension here is explicit — no Center, no
    // Expanded cross-axis ambiguity — so this can't reproduce the
    // unbounded-constraint bug regardless of what wraps it.
    return Tooltip(
      message: dest.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Icon(
                selected ? dest.filledIcon : dest.outlineIcon,
                color: selected ? AppTheme.paper : AppTheme.muted,
                size: 24,
              ),
            ),
          ),
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
