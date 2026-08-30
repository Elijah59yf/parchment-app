import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/role_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/current_user_provider.dart';
import '../models/announcement.dart';
import '../providers/announcements_provider.dart';
import 'compose_announcement_screen.dart';

/// Full-content view for a single announcement. Marks it read on open
/// (fire-and-forget, matching how markAsRead is treated elsewhere -
/// a failed read receipt shouldn't block or interrupt reading), and
/// surfaces edit/delete for whoever the backend would actually allow
/// to use them (the author, or any admin); mirrors the permission
/// check in updateAnnouncement/deleteAnnouncement server-side, so the
/// UI never offers an action the API would just 403 on.
class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  late Announcement _announcement;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _announcement = widget.announcement;
    // Fire-and-forget: same best-effort treatment as everywhere else
    // read receipts are recorded.
    ref.read(announcementsProvider.notifier).markAsRead(_announcement.id);
  }

  bool _canManage(String currentUserId, String currentUserRole) {
    return currentUserRole == 'admin' || currentUserId == _announcement.authorId;
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<Announcement>(
      MaterialPageRoute(
        builder: (context) =>
            ComposeAnnouncementScreen(existing: _announcement),
      ),
    );
    if (result != null && mounted) {
      setState(() => _announcement = result);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.dio.delete('/announcements/${_announcement.id}');
      ref.read(announcementsProvider.notifier).removeLocal(_announcement.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      final data = e.response?.data;
      final message = (data is Map && data['error'] is String)
          ? data['error'] as String
          : 'Couldn\'t delete this post. Please try again.';
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final dateFormat = DateFormat('MMMM d, y \u2022 h:mm a');

    return Scaffold(
      appBar: AppBar(
        actions: [
          currentUser.maybeWhen(
            data: (user) {
              if (!_canManage(user.id, user.role)) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _isDeleting ? null : _edit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: _isDeleting ? null : _confirmDelete,
                    icon: _isDeleting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_announcement.isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin, size: 16, color: AppTheme.ink),
                      const SizedBox(width: 6),
                      Text(
                        'PINNED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                      ),
                    ],
                  ),
                ),
              Text(
                _announcement.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _announcement.authorName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  RoleBadge(role: _announcement.authorRole),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(_announcement.createdAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Divider(height: 32),
              Text(
                _announcement.body,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
