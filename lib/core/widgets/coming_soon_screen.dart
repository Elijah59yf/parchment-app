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
class ComingSoonBody extends StatelessWidget {
  const ComingSoonBody({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
