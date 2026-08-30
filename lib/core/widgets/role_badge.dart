import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small role indicator. Originally announcement-author-only (admin/rep,
/// since students can't post, gated server-side by requireRole
/// ('admin', 'rep') on POST /announcements), now also used generically
/// in User Management where all three roles appear.
///
/// Admin is filled solid ink; rep is outlined; student is plain muted
/// text with no border, sitting a level below rep since it carries no
/// special permissions. No new colors anywhere: fill vs. outline vs.
/// plain text is the entire hierarchy signal, keeping this consistent
/// with the rest of the monochrome UI.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final String role; // 'admin' | 'rep' | 'student'

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case 'admin':
        return _badge(label: 'ADMIN', filled: true, bordered: true);
      case 'rep':
        return _badge(label: 'REP', filled: false, bordered: true);
      default:
        return _badge(label: 'STUDENT', filled: false, bordered: false);
    }
  }

  Widget _badge({
    required String label,
    required bool filled,
    required bool bordered,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? AppTheme.ink : Colors.transparent,
        border: bordered ? Border.all(color: AppTheme.border, width: 1) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: filled ? AppTheme.paper : AppTheme.muted,
        ),
      ),
    );
  }
}
