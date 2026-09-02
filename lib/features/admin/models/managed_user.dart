/// Matches SAFE_USER_FIELDS from users.controller.js: the shape
/// returned by GET /users, GET /users/:id, and the role/status PATCH
/// endpoints. Distinct from CurrentUser (features/auth) which covers
/// the same columns for the /users/me self-service case; kept separate
/// since they serve different screens and it's fine for them to drift
/// independently if either endpoint's shape changes later.
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.matricNumber,
    required this.role,
    required this.cohortYear,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String matricNumber;
  final String role; // 'admin' | 'rep' | 'student'
  final int cohortYear;
  final bool isActive;
  final DateTime createdAt;

  /// Kept for the display call sites (user list, edit screen) that
  /// just want one string - the backend still stores first/last
  /// separately, this just joins them for convenience here.
  String get fullName => '$firstName $lastName';

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      matricNumber: json['matric_number'] as String,
      role: json['role'] as String,
      cohortYear: json['cohort_year'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ManagedUser copyWith({String? role, bool? isActive}) {
    return ManagedUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      matricNumber: matricNumber,
      role: role ?? this.role,
      cohortYear: cohortYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
