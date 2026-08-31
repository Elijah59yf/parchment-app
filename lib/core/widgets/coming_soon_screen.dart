import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown in nav tabs whose real feature hasn't been built yet
/// (Dashboard, Materials, Polls, Manage, Admin hub — build order
/// steps 4-7). Swap each usage out for the real screen as that
/// feature lands; this widget itself can eventually be deleted once
/// nothing references it.
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
      body: Center(
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
