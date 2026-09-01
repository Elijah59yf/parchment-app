import 'faculty.dart';

/// Matches the row shape from /settings/departments. GET embeds a
/// nested `faculty: { id, code, name }` (settings.controller.js
/// listDepartments does `select('*, faculty:faculty_id(id, code,
/// name)')`), but POST/PATCH responses only return the bare
/// department row — so `faculty` is nullable here and the screen
/// resolves the faculty name itself from the already-loaded faculty
/// list rather than depending on it being present.
class Department {
  const Department({
    required this.id,
    required this.code,
    required this.name,
    required this.facultyId,
    this.faculty,
  });

  final String id;
  final String code; // 2-digit string, e.g. "08"
  final String name; // e.g. "Computer Engineering"
  final String facultyId;
  final Faculty? faculty;

  factory Department.fromJson(Map<String, dynamic> json) {
    final facultyJson = json['faculty'] as Map<String, dynamic>?;
    return Department(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      facultyId: json['faculty_id'] as String,
      faculty: facultyJson != null ? Faculty.fromJson(facultyJson) : null,
    );
  }

  Department copyWith({
    String? code,
    String? name,
    String? facultyId,
    Faculty? faculty,
  }) {
    return Department(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      facultyId: facultyId ?? this.facultyId,
      faculty: faculty ?? this.faculty,
    );
  }
}
