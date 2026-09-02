import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// One entry in the "what moved" list returned by a clock update -
/// see updateSessionClock's doc comment on the backend for why this
/// endpoint reports changes rather than performing any reconciliation
/// itself.
class CohortSpaceChange {
  const CohortSpaceChange({
    required this.cohortId,
    required this.cohortYear,
    required this.departmentId,
    required this.isOverridden,
    required this.fromLevel,
    required this.fromSemester,
    required this.toLevel,
    required this.toSemester,
  });

  final String cohortId;
  final int cohortYear;
  final String departmentId;
  final bool isOverridden;
  final int? fromLevel;
  final int? fromSemester;
  final int toLevel;
  final int toSemester;

  factory CohortSpaceChange.fromJson(Map<String, dynamic> json) {
    final from = json['from'] as Map<String, dynamic>?;
    final to = json['to'] as Map<String, dynamic>;
    return CohortSpaceChange(
      cohortId: json['cohortId'] as String,
      cohortYear: json['cohortYear'] as int,
      departmentId: json['departmentId'] as String,
      isOverridden: json['isOverridden'] as bool,
      fromLevel: from?['level'] as int?,
      fromSemester: from?['semester'] as int?,
      toLevel: to['level'] as int,
      toSemester: to['semester'] as int,
    );
  }
}

class SessionClockState {
  const SessionClockState({
    this.currentSession,
    this.currentSemester,
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  /// e.g. "2025/2026". Null until the clock has been set for the
  /// first time (matches the backend's "not set yet" 409 case).
  final String? currentSession;

  /// 1 or 2. Null alongside currentSession when unset.
  final int? currentSemester;

  final bool isLoading;
  final bool isSaving;
  final String? error;

  SessionClockState copyWith({
    String? currentSession,
    int? currentSemester,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SessionClockState(
      currentSession: currentSession ?? this.currentSession,
      currentSemester: currentSemester ?? this.currentSemester,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SessionClockNotifier extends StateNotifier<SessionClockState> {
  SessionClockNotifier(this._dio) : super(const SessionClockState()) {
    load();
  }

  final Dio _dio;

  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return fallback;
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/settings/session-clock');
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(
        currentSession: data['currentSession'] as String?,
        currentSemester: data['currentSemester'] as int?,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e, "Couldn't load the session clock."),
      );
    } catch (e) {
      // Same reasoning as the other admin providers: a non-Dio failure
      // must still clear isLoading, or this spins forever with no error.
      state = state.copyWith(isLoading: false, error: "Couldn't load the session clock: $e");
    }
  }

  /// Applies the clock update immediately (this isn't a dry run - see
  /// the backend doc comment) and returns which cohorts' level/semester
  /// moved as a result, so the screen can show the caller what changed.
  /// Throws DioException on failure so the screen can show the
  /// backend's exact validation message.
  Future<List<CohortSpaceChange>> update({
    required String currentSession,
    required int currentSemester,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final response = await _dio.patch('/settings/session-clock', data: {
        'currentSession': currentSession,
        'currentSemester': currentSemester,
      });
      final data = response.data as Map<String, dynamic>;
      final changes = (data['changedCohorts'] as List)
          .cast<Map<String, dynamic>>()
          .map(CohortSpaceChange.fromJson)
          .toList();
      state = state.copyWith(
        currentSession: data['currentSession'] as String,
        currentSemester: data['currentSemester'] as int,
      );
      return changes;
    } finally {
      // Always clear isSaving, whether the request succeeded, threw a
      // DioException the dialog will show, or threw anything else -
      // otherwise the Save button would stay disabled after a failure.
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final sessionClockProvider = StateNotifierProvider<SessionClockNotifier, SessionClockState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SessionClockNotifier(apiClient.dio);
});
