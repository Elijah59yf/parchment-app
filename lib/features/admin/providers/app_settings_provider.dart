import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Two app-wide boolean flags, both stored as ordinary rows in the
/// generic key/value `settings` table (see settings.controller.js's
/// getSetting/updateSetting) - no dedicated backend endpoints needed,
/// same mechanism the seeded `keepalive_enabled` row already uses.
class AppSettingsState {
  const AppSettingsState({
    this.keepaliveEnabled = true,
    this.twoFactorEnabled = false,
    this.isLoading = true,
    this.error,
  });

  final bool keepaliveEnabled;
  final bool twoFactorEnabled;
  final bool isLoading;
  final String? error;

  AppSettingsState copyWith({
    bool? keepaliveEnabled,
    bool? twoFactorEnabled,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AppSettingsState(
      keepaliveEnabled: keepaliveEnabled ?? this.keepaliveEnabled,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier(this._dio) : super(const AppSettingsState()) {
    load();
  }

  final Dio _dio;

  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return fallback;
  }

  /// getSetting 404s for a key that's never been written - that's
  /// expected for two_factor_enabled until the first toggle, so it
  /// falls back to [defaultValue] instead of surfacing as an error.
  Future<bool> _fetchBool(String key, {required bool defaultValue}) async {
    try {
      final response = await _dio.get('/settings/$key');
      final data = response.data as Map<String, dynamic>;
      final setting = data['setting'] as Map<String, dynamic>;
      final value = setting['value'];
      return value is bool ? value : defaultValue;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return defaultValue;
      rethrow;
    }
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final keepalive = await _fetchBool('keepalive_enabled', defaultValue: true);
      final twoFactor = await _fetchBool('two_factor_enabled', defaultValue: false);
      state = state.copyWith(
        keepaliveEnabled: keepalive,
        twoFactorEnabled: twoFactor,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(e, "Couldn't load app settings."),
      );
    } catch (e) {
      // Same reasoning as the other admin providers: a non-Dio failure
      // must still clear isLoading, or this spins forever with no error.
      state = state.copyWith(isLoading: false, error: "Couldn't load app settings: $e");
    }
  }

  Future<void> setKeepalive(bool value) => _setBool(
        key: 'keepalive_enabled',
        value: value,
        apply: (s, v) => s.copyWith(keepaliveEnabled: v),
      );

  Future<void> setTwoFactor(bool value) => _setBool(
        key: 'two_factor_enabled',
        value: value,
        apply: (s, v) => s.copyWith(twoFactorEnabled: v),
      );

  /// Optimistic: flips the switch immediately, then reverts if the
  /// PUT fails, so the UI doesn't lag behind a tap - matching how
  /// Allowed Cohorts' active toggle already behaves.
  Future<void> _setBool({
    required String key,
    required bool value,
    required AppSettingsState Function(AppSettingsState, bool) apply,
  }) async {
    final previous = state;
    state = apply(state, value);
    try {
      await _dio.put('/settings/$key', data: {'value': value});
    } on DioException {
      state = previous;
      rethrow;
    }
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AppSettingsNotifier(apiClient.dio);
});
