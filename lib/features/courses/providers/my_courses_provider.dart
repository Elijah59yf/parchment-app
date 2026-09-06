import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/course.dart';

class MyCoursesState {
  const MyCoursesState({
    this.core = const [],
    this.myElectives = const [],
    this.availableElectives = const [],
    this.level,
    this.semester,
    this.isLoading = true,
    this.error,
  });

  final List<Course> core;
  final List<Course> myElectives;
  final List<Course> availableElectives;

  /// The caller's own currently-computed level/semester (see
  /// computeStudentSpace on the backend) - shown as context for why
  /// this exact course list is what's showing.
  final int? level;
  final int? semester;

  final bool isLoading;
  final String? error;

  MyCoursesState copyWith({
    List<Course>? core,
    List<Course>? myElectives,
    List<Course>? availableElectives,
    int? level,
    int? semester,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MyCoursesState(
      core: core ?? this.core,
      myElectives: myElectives ?? this.myElectives,
      availableElectives: availableElectives ?? this.availableElectives,
      level: level ?? this.level,
      semester: semester ?? this.semester,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MyCoursesNotifier extends StateNotifier<MyCoursesState> {
  MyCoursesNotifier(this._dio) : super(const MyCoursesState()) {
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
      final response = await _dio.get('/courses/mine');
      final data = response.data as Map<String, dynamic>;
      final space = data['space'] as Map<String, dynamic>;
      state = state.copyWith(
        core: (data['core'] as List).cast<Map<String, dynamic>>().map(Course.fromJson).toList(),
        myElectives: (data['myElectives'] as List)
            .cast<Map<String, dynamic>>()
            .map(Course.fromJson)
            .toList(),
        availableElectives: (data['availableElectives'] as List)
            .cast<Map<String, dynamic>>()
            .map(Course.fromJson)
            .toList(),
        level: space['level'] as int,
        semester: space['semester'] as int,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMessage(e, "Couldn't load courses."));
    } catch (e) {
      // Same reasoning as the other providers: a non-Dio failure must
      // still clear isLoading, or this spins forever with no error.
      state = state.copyWith(isLoading: false, error: "Couldn't load courses: $e");
    }
  }

  /// Optimistic: moves the course between the two elective lists
  /// immediately, reverts on failure - same pattern as the admin
  /// providers' toggle actions.
  Future<void> register(Course course) async {
    final previous = state;
    state = state.copyWith(
      myElectives: [...state.myElectives, course],
      availableElectives: state.availableElectives.where((c) => c.id != course.id).toList(),
    );
    try {
      await _dio.post('/courses/${course.id}/register');
    } on DioException catch (e) {
      state = previous;
      throw _errorMessage(e, "Couldn't register for this course.");
    }
  }

  Future<void> unregister(Course course) async {
    final previous = state;
    state = state.copyWith(
      myElectives: state.myElectives.where((c) => c.id != course.id).toList(),
      availableElectives: [...state.availableElectives, course],
    );
    try {
      await _dio.delete('/courses/${course.id}/register');
    } on DioException catch (e) {
      state = previous;
      throw _errorMessage(e, "Couldn't drop this course.");
    }
  }
}

final myCoursesProvider = StateNotifierProvider<MyCoursesNotifier, MyCoursesState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MyCoursesNotifier(apiClient.dio);
});
