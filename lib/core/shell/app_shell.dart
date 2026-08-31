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
/// Every role uses the SAME custom `_BarItem` (icon-only, ink pill on
/// selection, name revealed via long-press tooltip) instead of mixing
/// that with stock Material `NavigationBar` for student/rep. Went
/// through two iterations before landing here:
///   1. Stock NavigationBar (student/rep) + custom pill (admin) — two
///      different behaviors in the same app: NavigationBar put labels
///      *under* the icon, the custom pill put them *beside* it.
///   2. Unified custom pill, label beside icon, shown only when
///      selected — fixed the inconsistency, but `Flexible` for the
///      label sat inside a `Row(mainAxisSize: min)` inside a `Center`
///      (unbounded width), which is invalid Flutter layout: no bounded
///      space to flex into, so the text silently rendered as nothing
///      instead of erroring loudly.
/// Icon-only sidesteps the whole class of bug — a fixed-size circle
/// can never overflow regardless of screen width or item count — and
/// every screen already shows its own name in its app bar anyway, so
/// the label was redundant besides.
///
/// admin additionally gets a centered, elevated, notched FAB for Admin
/// instead of it being a 7th flat item (7 was cramped — Material's own
/// guidance caps a standard bottom bar at 5).
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

    return Scaffold(
      body: navigationShell,
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
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
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
              // Reserves the gap the FAB notch sits in. Fixed width is
              // safe here — it's the Expanded items on either side that
              // absorb any extra/short space, so the Row can never
              // overflow regardless of screen width or label length.
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
    );
  }
}

/// The plain (non-notched) bar used for student/rep.
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
    // Icon-only: no label ever renders here. Every screen already
    // shows its own name in its app bar, so a nav label was pure
    // redundancy — and it was also the source of every layout bug
    // (wrapping, overflow, text vanishing entirely when Flexible sat
    // inside an unbounded-width Center). A fixed-size circle can never
    // overflow no matter the screen width or item count. Long-press
    // still reveals the name via the platform's native tooltip.
    return Tooltip(
      message: dest.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppTheme.ink : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? dest.filledIcon : dest.outlineIcon,
              color: selected ? AppTheme.paper : AppTheme.muted,
              size: 24,
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
