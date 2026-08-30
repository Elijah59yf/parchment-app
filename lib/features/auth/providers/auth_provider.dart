import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(storage);
});

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Tracks whether the app currently has a usable session. Splash reads
/// this to decide where to route on launch. Kept intentionally simple
/// for now: presence of a refresh token is treated as "authenticated" —
/// if it's actually expired/revoked, the first authenticated API call
/// will fail with 401 and the app can fall back to login then. Full
/// eager validation against the backend can be added later if needed.
class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  AuthStatusNotifier(this._tokenStorage) : super(AuthStatus.unknown) {
    _checkStoredSession();
  }

  final TokenStorage _tokenStorage;

  Future<void> _checkStoredSession() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    state = refreshToken != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    state = AuthStatus.unauthenticated;
  }

  void setAuthenticated() {
    state = AuthStatus.authenticated;
  }
}

final authStatusProvider =
    StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return AuthStatusNotifier(storage);
});
