import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/announcement.dart';

const int _pageSize = 20;

/// Feed state: the loaded items plus enough bookkeeping to drive
/// pull-to-refresh and infinite scroll without extra round trips.
class AnnouncementsState {
  const AnnouncementsState({
    this.items = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Announcement> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  AnnouncementsState copyWith({
    List<Announcement>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return AnnouncementsState(
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AnnouncementsNotifier extends StateNotifier<AnnouncementsState> {
  AnnouncementsNotifier(this._dio, {this.authorId})
      : super(const AnnouncementsState()) {
    loadInitial();
  }

  final Dio _dio;

  /// When set, scopes every fetch to one author's posts; powers the
  /// "My Announcements" screen. Null means the unfiltered main feed.
  final String? authorId;

  Future<void> loadInitial() async {
    state = state.copyWith(isInitialLoading: true, clearError: true);
    try {
      final response = await _dio.get(
        '/announcements',
        queryParameters: {
          'limit': _pageSize,
          'offset': 0,
          if (authorId != null) 'authorId': authorId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['announcements'] as List)
          .cast<Map<String, dynamic>>()
          .map(Announcement.fromJson)
          .toList();

      state = state.copyWith(
        items: list,
        isInitialLoading: false,
        hasMore: list.length == _pageSize,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isInitialLoading: false,
        error: _errorMessage(e),
      );
    }
  }

  /// Pull-to-refresh: same as loadInitial but callable repeatedly.
  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isInitialLoading) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final response = await _dio.get(
        '/announcements',
        queryParameters: {
          'limit': _pageSize,
          'offset': state.items.length,
          if (authorId != null) 'authorId': authorId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['announcements'] as List)
          .cast<Map<String, dynamic>>()
          .map(Announcement.fromJson)
          .toList();

      state = state.copyWith(
        items: [...state.items, ...list],
        isLoadingMore: false,
        hasMore: list.length == _pageSize,
      );
    } on DioException catch (e) {
      // Keep existing items; just surface the error and stop paging.
      state = state.copyWith(isLoadingMore: false, error: _errorMessage(e));
    }
  }

  /// Inserts a just-created announcement at the top of the in-memory
  /// list (pinned or not; the backend sorts pinned-first on its own
  /// next real fetch, but showing it immediately at the top is the
  /// right call either way since it's the newest post regardless).
  /// Avoids a network round trip just to see your own post appear.
  void prependPosted(Announcement announcement) {
    state = state.copyWith(items: [announcement, ...state.items]);
  }

  /// Replaces one item in-place after a successful PATCH, keyed by id.
  /// No-op if the item isn't currently in the loaded list (e.g. it was
  /// on a page that hasn't loaded yet).
  void updateLocal(Announcement updated) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == updated.id) updated else item,
      ],
    );
  }

  /// Removes one item after a successful DELETE, keyed by id.
  void removeLocal(String announcementId) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != announcementId).toList(),
    );
  }

  /// Best-effort: a failed read receipt shouldn't interrupt reading.
  Future<void> markAsRead(String announcementId) async {
    try {
      await _dio.post('/announcements/$announcementId/read');
    } on DioException {
      // Swallow (see doc comment above).
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return 'Couldn\'t load announcements. Pull down to try again.';
  }
}

final announcementsProvider =
    StateNotifierProvider<AnnouncementsNotifier, AnnouncementsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnnouncementsNotifier(apiClient.dio);
});

/// One scoped instance per author id; powers "My Announcements".
/// autoDispose since this is only needed while that screen is open;
/// no reason to keep it alive (and re-fetching) once the user leaves.
final myAnnouncementsProvider = StateNotifierProvider.autoDispose
    .family<AnnouncementsNotifier, AnnouncementsState, String>(
  (ref, authorId) {
    final apiClient = ref.watch(apiClientProvider);
    return AnnouncementsNotifier(apiClient.dio, authorId: authorId);
  },
);
