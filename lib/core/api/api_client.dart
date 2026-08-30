import 'package:dio/dio.dart';
import '../../features/auth/data/token_storage.dart';

/// Single Dio instance for all API calls. Base URL should point at your
/// Render-deployed backend (or localhost during development).
///
/// TODO: move this to an env-based config (--dart-define) before release
/// so dev/prod URLs aren't hardcoded here.
const String kApiBaseUrl = 'https://your-backend.onrender.com';

class ApiClient {
  ApiClient(this._tokenStorage, {this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // Render free tier can cold-start slowly; a generous timeout
        // avoids false "network error" states on the first request
        // after the backend has been idle.
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isRefreshCall = error.requestOptions.path == '/auth/refresh';
          final alreadyRetried =
              error.requestOptions.extra['retried'] == true;

          if (!isUnauthorized || isRefreshCall || alreadyRetried) {
            handler.next(error);
            return;
          }

          try {
            final newAccessToken = await _refreshAccessToken();
            if (newAccessToken == null) {
              await _handleSessionExpired();
              handler.next(error);
              return;
            }

            // Retry the original request with the new token.
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            retryOptions.extra['retried'] = true;
            final response = await _dio.fetch(retryOptions);
            handler.resolve(response);
          } catch (_) {
            await _handleSessionExpired();
            handler.next(error);
          }
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final Future<void> Function()? onSessionExpired;
  late final Dio _dio;

  // Single-flight guard: if several requests 401 around the same time
  // (e.g. a screen fires 3 API calls at once), only the first triggers
  // an actual refresh call — the rest await that same in-flight future
  // instead of racing to refresh (and rotate the refresh token) in
  // parallel, which would invalidate each other.
  Future<String?>? _refreshInFlight;

  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return null;

    // Plain, un-intercepted Dio for the refresh call itself, so it never
    // recurses into this same onError handler.
    final plainDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
    final response = await plainDio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final newAccessToken = response.data['accessToken'] as String?;
    final newRefreshToken = response.data['refreshToken'] as String?;
    if (newAccessToken == null || newRefreshToken == null) return null;

    await _tokenStorage.saveTokens(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );
    return newAccessToken;
  }

  Future<void> _handleSessionExpired() async {
    await _tokenStorage.clear();
    await onSessionExpired?.call();
  }

  Dio get dio => _dio;
}
