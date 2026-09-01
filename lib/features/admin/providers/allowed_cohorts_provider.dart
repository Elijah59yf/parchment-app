import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/allowed_cohort.dart';
import '../models/department.dart';
import '../models/faculty.dart';

class AllowedCohortsState {
  const AllowedCohortsState({
    this.cohorts = const [],
    this.isLoading = true,
    this.error,
  });

  final List<AllowedCohort> cohorts;
  final bool isLoading;
  final String? error;

  AllowedCohortsState copyWith({
    List<AllowedCohort>? cohorts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AllowedCohortsState(
      cohorts: cohorts ?? this.cohorts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AllowedCohortsNotifier extends StateNotifier<AllowedCohortsState> {
  AllowedCohortsNotifier(this._dio) : super(const AllowedCohortsState()) {
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
      final response = await _dio.get('/settings/cohorts');
      final cohorts = ((response.data as Map<String, dynamic>)['cohorts'] as List)
          .cast<Map<String, dynamic>>()
          .map(AllowedCohort.fromJson)
          .toList();
      state = state.copyWith(cohorts: cohorts, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e, "Couldn't load allowed cohorts."),
      );
    }
  }

  /// Throws DioException on failure (e.g. 409 duplicate cohort) so the
  /// dialog can show the backend's exact message rather than a generic one.
  Future<void> create({
    required int cohortYear,
    required String facultyId,
    required String departmentId,
    Faculty? faculty,
    Department? department,
  }) async {
    final response = await _dio.post('/settings/cohorts', data: {
      'cohortYear': cohortYear,
      'facultyId': facultyId,
      'departmentId': departmentId,
    });
    var cohort = AllowedCohort.fromJson((response.data as Map<String, dynamic>)['cohort']);
    // POST response has no embedded faculty/department (see model doc)
    // - attach them locally from what the dialog already had loaded.
    cohort = cohort.copyWith(faculty: faculty, department: department);
    state = state.copyWith(
      cohorts: [...state.cohorts, cohort]
        ..sort((a, b) => b.cohortYear.compareTo(a.cohortYear)),
    );
  }

  Future<void> setActive(String id, bool isActive) async {
    final response = await _dio.patch('/settings/cohorts/$id', data: {'isActive': isActive});
    final updated = AllowedCohort.fromJson((response.data as Map<String, dynamic>)['cohort']);
    _replace(id, (existing) => updated.copyWith(
      faculty: existing.faculty,
      department: existing.department,
    ));
  }

  /// Pass null to clear either override and let it resume tracking
  /// the global session clock. Omit a param entirely to leave that
  /// field unchanged - matches setCohortOverrideSchema's semantics
  /// (undefined = untouched, null = clear).
  Future<void> setOverride(
    String id, {
    int? levelOverride,
    bool clearLevelOverride = false,
    int? semesterOverride,
    bool clearSemesterOverride = false,
  }) async {
    final data = <String, dynamic>{};
    if (levelOverride != null || clearLevelOverride) {
      data['levelOverride'] = clearLevelOverride ? null : levelOverride;
    }
    if (semesterOverride != null || clearSemesterOverride) {
      data['semesterOverride'] = clearSemesterOverride ? null : semesterOverride;
    }

    final response = await _dio.patch('/settings/cohorts/$id/override', data: data);
    final updated = AllowedCohort.fromJson((response.data as Map<String, dynamic>)['cohort']);
    _replace(id, (existing) => updated.copyWith(
      faculty: existing.faculty,
      department: existing.department,
    ));
  }

  Future<void> delete(String id) async {
    await _dio.delete('/settings/cohorts/$id');
    state = state.copyWith(cohorts: state.cohorts.where((c) => c.id != id).toList());
  }

  void _replace(String id, AllowedCohort Function(AllowedCohort existing) update) {
    state = state.copyWith(
      cohorts: [
        for (final c in state.cohorts) if (c.id == id) update(c) else c,
      ],
    );
  }
}

final allowedCohortsProvider =
    StateNotifierProvider<AllowedCohortsNotifier, AllowedCohortsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AllowedCohortsNotifier(apiClient.dio);
});
