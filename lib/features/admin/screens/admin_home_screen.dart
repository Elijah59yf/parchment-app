import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import 'faculty_department_screen.dart';
import 'user_management_screen.dart';

/// Landing screen for the Admin tab (bottom-nav branch 6, admin role
/// only). Each row pushes its own screen via the root navigator - not
/// a go_router sub-route - matching how Feed's app-bar actions already
/// push UserManagementScreen, so admin tooling stays consistent
/// whether it's reached from here or from Feed.
///
/// Allowed Cohorts and App Settings are still ComingSoonScreen; they
/// route the same way the rest of this list will once built, so no
/// further wiring is needed here when they land.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _AdminTile(
            icon: Icons.account_balance_outlined,
            title: 'Faculties & Departments',
            subtitle: 'Manage the faculty/department structure',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FacultyDepartmentScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.groups_outlined,
            title: 'Allowed Cohorts',
            subtitle: 'Control which cohorts can register and log in',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonScreen(
                  title: 'Allowed Cohorts',
                  icon: Icons.groups_outlined,
                ),
              ),
            ),
          ),
          _AdminTile(
            icon: Icons.tune_outlined,
            title: 'App Settings',
            subtitle: 'Session/semester clock and app-wide toggles',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonScreen(
                  title: 'App Settings',
                  icon: Icons.tune_outlined,
                ),
              ),
            ),
          ),
          const Divider(height: 32),
          _AdminTile(
            icon: Icons.people_outline,
            title: 'User Management',
            subtitle: 'Roles and account status',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.ink,
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.subtle),
      onTap: onTap,
    );
  }
}
