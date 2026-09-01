import 'department.dart';
import 'faculty.dart';

/// Matches the row shape from /settings/cohorts (settings.controller.js
/// listAllowedCohorts does `select('*, faculty:faculty_id(...),
/// department:department_id(...)')`). POST/PATCH responses only
/// return the bare cohort row (no embedded faculty/department), same
/// caveat as Department.fromJson — the provider re-attaches them
/// locally from already-loaded state after create/update.
class AllowedCohort {
  const AllowedCohort({
    required this.id,
    required this.cohortYear,
    required this.facultyId,
    required this.departmentId,
    required this.isActive,
    this.levelOverride,
    this.semesterOverride,
    this.faculty,
    this.department,
  });

  final String id;
  final int cohortYear;
  final String facultyId;
  final String departmentId;
  final bool isActive;

  /// Per-cohort override for the global session clock. Null means
  /// "track the clock normally" for that field; a 100-multiple (100,
  /// 200, ...) pins the level, 1 or 2 pins the semester, regardless
  /// of what the global session clock currently says.
  final int? levelOverride;
  final int? semesterOverride;

  final Faculty? faculty;
  final Department? department;

  bool get hasOverride => levelOverride != null || semesterOverride != null;

  factory AllowedCohort.fromJson(Map<String, dynamic> json) {
    final facultyJson = json['faculty'] as Map<String, dynamic>?;
    final departmentJson = json['department'] as Map<String, dynamic>?;
    return AllowedCohort(
      id: json['id'] as String,
      cohortYear: json['cohort_year'] as int,
      facultyId: json['faculty_id'] as String,
      departmentId: json['department_id'] as String,
      isActive: json['is_active'] as bool,
      levelOverride: json['level_override'] as int?,
      semesterOverride: json['semester_override'] as int?,
      faculty: facultyJson != null ? Faculty.fromJson(facultyJson) : null,
      department: departmentJson != null ? Department.fromJson(departmentJson) : null,
    );
  }

  AllowedCohort copyWith({
    bool? isActive,
    int? levelOverride,
    int? semesterOverride,
    bool clearLevelOverride = false,
    bool clearSemesterOverride = false,
    Faculty? faculty,
    Department? department,
  }) {
    return AllowedCohort(
      id: id,
      cohortYear: cohortYear,
      facultyId: facultyId,
      departmentId: departmentId,
      isActive: isActive ?? this.isActive,
      levelOverride: clearLevelOverride ? null : (levelOverride ?? this.levelOverride),
      semesterOverride:
          clearSemesterOverride ? null : (semesterOverride ?? this.semesterOverride),
      faculty: faculty ?? this.faculty,
      department: department ?? this.department,
    );
  }
}
