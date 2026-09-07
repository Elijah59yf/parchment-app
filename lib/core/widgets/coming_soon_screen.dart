import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown in nav tabs whose real feature hasn't been built yet
/// (Polls, Manage, Admin hub — build order steps still pending).
/// Swap each usage out for the real screen as that feature lands;
/// this widget itself can eventually be deleted once nothing
/// references it.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ComingSoonBody(icon: icon),
    );
  }
}

/// Just the "Coming soon" icon + text, no Scaffold/AppBar of its own -
/// for use as a tab body inside a screen that already owns its own
/// Scaffold (e.g. Study's Timetable/Materials sub-tabs, which live
/// inside a TabBarView and would otherwise get a nested, duplicate
/// AppBar if they used ComingSoonScreen directly).
///
/// SizedBox.expand + Align rather than a bare Center: this widget gets
/// reused in more than one kind of parent (Scaffold.body, TabBarView),
/// and a bare Center trusts whatever ambient constraints its parent
/// happens to hand it are bounded - which has bitten this exact file
/// before (see the layout-bug note in app_shell.dart's doc comment).
/// SizedBox.expand pins its own size to whatever bounded constraints
/// its parent DOES provide, so there's nothing left for a Center here
/// to get wrong regardless of which parent hosts it.
class ComingSoonBody extends StatelessWidget {
  const ComingSoonBody({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.subtle),
            const SizedBox(height: 12),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
