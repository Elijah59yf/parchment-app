/// Matches the row shape returned by every /settings/faculties
/// endpoint (settings.controller.js listFaculties/createFaculty/
/// updateFaculty) — a straight `select('*')` off the `faculties`
/// table, no joins.
class Faculty {
  const Faculty({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code; // 2-digit string, e.g. "04"
  final String name; // e.g. "Engineering"

  factory Faculty.fromJson(Map<String, dynamic> json) {
    return Faculty(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }

  Faculty copyWith({String? code, String? name}) {
    return Faculty(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
    );
  }
}
