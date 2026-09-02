import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/department.dart';
import '../models/faculty.dart';

/// Faculties and departments are loaded and edited together on one
/// screen (departments nest under their faculty in the UI, and every
/// department create/edit needs the faculty list for its dropdown),
/// so they share a single notifier rather than two providers that
/// would need to coordinate refreshes with each other.
class FacultyDepartmentState {
  const FacultyDepartmentState({
    this.faculties = const [],
    this.departments = const [],
    this.isLoading = true,
    this.error,
  });

  final List<Faculty> faculties;
  final List<Department> departments;
  final bool isLoading;
  final String? error;

  List<Department> departmentsFor(String facultyId) =>
      departments.where((d) => d.facultyId == facultyId).toList();

  FacultyDepartmentState copyWith({
    List<Faculty>? faculties,
    List<Department>? departments,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FacultyDepartmentState(
      faculties: faculties ?? this.faculties,
      departments: departments ?? this.departments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FacultyDepartmentNotifier extends StateNotifier<FacultyDepartmentState> {
  FacultyDepartmentNotifier(this._dio) : super(const FacultyDepartmentState()) {
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
      final results = await Future.wait([
        _dio.get('/settings/faculties'),
        _dio.get('/settings/departments'),
      ]);

      final faculties = ((results[0].data as Map<String, dynamic>)['faculties'] as List)
          .cast<Map<String, dynamic>>()
          .map(Faculty.fromJson)
          .toList();
      final departments = ((results[1].data as Map<String, dynamic>)['departments'] as List)
          .cast<Map<String, dynamic>>()
          .map(Department.fromJson)
          .toList();

      state = state.copyWith(
        faculties: faculties,
        departments: departments,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e, "Couldn't load faculties and departments."),
      );
    } catch (e) {
      // Same reasoning as allowed_cohorts_provider.dart: a non-Dio
      // failure (bad response shape, a failed cast) would otherwise
      // fall through uncaught and leave isLoading stuck at true forever.
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load faculties and departments: $e",
      );
    }
  }

  Future<void> createFaculty({required String code, required String name}) async {
    final response = await _dio.post('/settings/faculties', data: {'code': code, 'name': name});
    final faculty = Faculty.fromJson((response.data as Map<String, dynamic>)['faculty']);
    state = state.copyWith(faculties: [...state.faculties, faculty]..sort((a, b) => a.code.compareTo(b.code)));
  }

  Future<void> updateFaculty(String id, {required String code, required String name}) async {
    final response = await _dio.patch('/settings/faculties/$id', data: {'code': code, 'name': name});
    final updated = Faculty.fromJson((response.data as Map<String, dynamic>)['faculty']);
    state = state.copyWith(
      faculties: [for (final f in state.faculties) if (f.id == id) updated else f]
        ..sort((a, b) => a.code.compareTo(b.code)),
    );
  }

  /// Deleting a faculty cascades to its departments and any allowed
  /// cohorts referencing it (schema.sql: `on delete cascade`) — the
  /// caller is expected to have already confirmed this with the user
  /// given how much that can quietly remove.
  Future<void> deleteFaculty(String id) async {
    await _dio.delete('/settings/faculties/$id');
    state = state.copyWith(
      faculties: state.faculties.where((f) => f.id != id).toList(),
      departments: state.departments.where((d) => d.facultyId != id).toList(),
    );
  }

  Future<void> createDepartment({
    required String code,
    required String name,
    required String facultyId,
  }) async {
    final response = await _dio.post('/settings/departments', data: {
      'code': code,
      'name': name,
      'facultyId': facultyId,
    });
    var department = Department.fromJson((response.data as Map<String, dynamic>)['department']);
    // POST response has no embedded `faculty` (see model doc) - attach
    // it locally so the UI doesn't need a special case for "just created".
    final faculty = state.faculties.where((f) => f.id == facultyId).firstOrNull;
    if (faculty != null) department = department.copyWith(faculty: faculty);
    state = state.copyWith(departments: [...state.departments, department]);
  }

  Future<void> updateDepartment(
    String id, {
    required String code,
    required String name,
    required String facultyId,
  }) async {
    final response = await _dio.patch('/settings/departments/$id', data: {
      'code': code,
      'name': name,
      'facultyId': facultyId,
    });
    var updated = Department.fromJson((response.data as Map<String, dynamic>)['department']);
    final faculty = state.faculties.where((f) => f.id == facultyId).firstOrNull;
    if (faculty != null) updated = updated.copyWith(faculty: faculty);
    state = state.copyWith(
      departments: [for (final d in state.departments) if (d.id == id) updated else d],
    );
  }

  Future<void> deleteDepartment(String id) async {
    await _dio.delete('/settings/departments/$id');
    state = state.copyWith(departments: state.departments.where((d) => d.id != id).toList());
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final facultyDepartmentProvider =
    StateNotifierProvider<FacultyDepartmentNotifier, FacultyDepartmentState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FacultyDepartmentNotifier(apiClient.dio);
});
