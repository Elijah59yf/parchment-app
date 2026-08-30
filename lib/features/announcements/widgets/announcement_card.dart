import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/role_badge.dart';
import '../models/announcement.dart';
import '../screens/announcement_detail_screen.dart';

/// Card summary of one announcement: title, truncated body, author +
/// role badge + date, push indicator when relevant. Shared between the
/// main Feed and My Announcements so both stay visually identical.
///
/// Default tap behavior pushes AnnouncementDetailScreen. Pass
/// [onReturn] when the caller needs to react after the detail screen
/// pops (e.g. My Announcements refreshing its own scoped list after a
/// possible edit/delete); the default push doesn't otherwise notify
/// anyone when the pushed route closes.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onReturn,
  });

  final Announcement announcement;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AnnouncementDetailScreen(announcement: announcement),
            ),
          );
          onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (announcement.isPinned) ...[
                    Icon(Icons.push_pin, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                announcement.body,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      announcement.authorName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  RoleBadge(role: announcement.authorRole),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(announcement.createdAt.toLocal()),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (announcement.sendPush) ...[
                    const Spacer(),
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
