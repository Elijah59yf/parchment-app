import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(
    storage,
    // If a 401 survives the refresh-and-retry attempt (refresh token
    // itself is expired/revoked), fall back to a real logout so the
    // router's redirect kicks the user to the login screen instead of
    // leaving them stuck on a screen silently failing every request.
    onSessionExpired: () => ref.read(authStatusProvider.notifier).logout(),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Tracks whether the app currently has a usable session. Splash reads
/// this to decide where to route on launch. Presence of a refresh token
/// is treated as "authenticated" on cold start — if it's actually
/// expired/revoked, ApiClient's refresh-and-retry interceptor will
/// discover that on the first authenticated call and call logout()
/// itself via onSessionExpired.
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
