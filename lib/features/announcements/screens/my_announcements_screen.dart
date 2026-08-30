import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/current_user_provider.dart';
import '../providers/announcements_provider.dart';
import '../widgets/announcement_card.dart';

/// A rep/admin's own posts. GET /announcements?authorId=<self>.
/// Reuses the same AnnouncementCard as the main Feed, and the same
/// AnnouncementDetailScreen for viewing/editing/deleting (that screen
/// already gates edit/delete on authorship or admin role, so nothing
/// extra is needed here for permissions).
///
/// Note: editing or deleting from here updates the main Feed's own
/// cached list (via announcementsProvider, which
/// AnnouncementDetailScreen writes through), but this screen's scoped
/// list only re-syncs when it refreshes itself, which is why every
/// card here refreshes this screen's list on return from its detail
/// push, rather than relying on cross-provider sync.
class MyAnnouncementsScreen extends ConsumerWidget {
  const MyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My announcements')),
      body: currentUser.when(
        data: (user) => _ScopedList(authorId: user.id),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Couldn\'t load your profile. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScopedList extends ConsumerStatefulWidget {
  const _ScopedList({required this.authorId});

  final String authorId;

  @override
  ConsumerState<_ScopedList> createState() => _ScopedListState();
}

class _ScopedListState extends ConsumerState<_ScopedList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(myAnnouncementsProvider(widget.authorId).notifier).loadMore();
    }
  }

  void _refresh() {
    ref.read(myAnnouncementsProvider(widget.authorId).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myAnnouncementsProvider(widget.authorId));

    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You haven\'t posted anything yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return AnnouncementCard(
            announcement: state.items[index],
            onReturn: _refresh,
          );
        },
      ),
    );
  }
}
