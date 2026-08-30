import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

/// The current user's own profile, from GET /users/me.
/// Used for role-gated UI (e.g. showing the compose FAB only to
/// admins/reps). Re-fetches whenever auth status flips to authenticated,
/// since that's the point a session actually exists to query with.
final currentUserProvider = FutureProvider<CurrentUser>((ref) async {
  // Re-run this provider whenever auth status changes.
  ref.watch(authStatusProvider);

  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.dio.get('/users/me');
  final data = response.data as Map<String, dynamic>;
  return CurrentUser.fromJson(data['user'] as Map<String, dynamic>);
});

class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.matricNumber,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String matricNumber;
  final String role; // 'admin' | 'rep' | 'student'

  bool get canPost => role == 'admin' || role == 'rep';

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      matricNumber: json['matric_number'] as String,
      role: json['role'] as String,
    );
  }
}
