/// Matches a row from the `courses` table (see courses.controller.js).
/// department_id is both ownership and visibility for this course -
/// see the schema comment on the courses table for why there's no
/// cross-department sharing at this level.
class Course {
  const Course({
    required this.id,
    required this.code,
    required this.title,
    required this.departmentId,
    required this.level,
    required this.semester,
    required this.courseType,
    required this.isActive,
    this.creditUnits,
  });

  final String id;
  final String code;
  final String title;
  final String departmentId;
  final int level;
  final int semester;
  final String courseType; // 'core' | 'elective'
  final bool isActive;
  final int? creditUnits;

  bool get isElective => courseType == 'elective';

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      departmentId: json['department_id'] as String,
      level: json['level'] as int,
      semester: json['semester'] as int,
      courseType: json['course_type'] as String,
      isActive: json['is_active'] as bool,
      creditUnits: json['credit_units'] as int?,
    );
  }
}
