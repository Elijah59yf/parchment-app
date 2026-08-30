import 'package:dio/dio.dart';
import '../../features/auth/data/token_storage.dart';

/// Single Dio instance for all API calls. Base URL should point at your
/// Render-deployed backend (or localhost during development).
///
/// TODO: move this to an env-based config (--dart-define) before release
/// so dev/prod URLs aren't hardcoded here.
const String kApiBaseUrl = 'https://papi.monarchdem.me';

class ApiClient {
  ApiClient(this._tokenStorage) {
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
      ),
    );
  }

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;
}
