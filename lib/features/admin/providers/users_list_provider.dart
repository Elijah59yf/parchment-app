import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/managed_user.dart';

/// GET /users returns the full cohort in one response; no pagination
/// on the backend for this endpoint (a "set" is a single cohort, so
/// this stays small; revisit with pagination if Parchment ever scales
/// beyond one set). ?role= filtering happens server-side when set;
/// the client-side name/matric search in the screen is separate and
/// operates on whatever's already been fetched.
class UsersListState {
  const UsersListState({
    this.users = const [],
    this.isLoading = true,
    this.error,
  });

  final List<ManagedUser> users;
  final bool isLoading;
  final String? error;

  UsersListState copyWith({
    List<ManagedUser>? users,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UsersListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UsersListNotifier extends StateNotifier<UsersListState> {
  UsersListNotifier(this._dio) : super(const UsersListState()) {
    load();
  }

  final Dio _dio;
  String? _roleFilter;

  Future<void> load({String? role}) async {
    _roleFilter = role;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get(
        '/users',
        queryParameters: {if (role != null) 'role': role},
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['users'] as List)
          .cast<Map<String, dynamic>>()
          .map(ManagedUser.fromJson)
          .toList();
      state = state.copyWith(users: list, isLoading: false);
    } on DioException catch (e) {
      final message = (e.response?.data is Map &&
              (e.response?.data as Map)['error'] is String)
          ? (e.response?.data as Map)['error'] as String
          : 'Couldn\'t load users. Pull down to try again.';
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  Future<void> refresh() => load(role: _roleFilter);

  void updateLocal(ManagedUser updated) {
    state = state.copyWith(
      users: [
        for (final user in state.users)
          if (user.id == updated.id) updated else user,
      ],
    );
  }
}

final usersListProvider =
    StateNotifierProvider<UsersListNotifier, UsersListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UsersListNotifier(apiClient.dio);
});
