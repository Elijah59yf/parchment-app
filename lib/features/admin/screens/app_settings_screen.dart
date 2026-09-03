import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/app_settings_provider.dart';

/// Admin-only. Two app-wide flags, both stored as plain rows in the
/// generic settings table - see app_settings_provider.dart. Note that
/// "two-factor" here is only a stored flag right now: there's no
/// OTP/email delivery or login-flow enforcement built yet, so toggling
/// it doesn't turn on real 2FA on its own - that's a separate,
/// considerably bigger feature (code generation, delivery, a
/// verification step in the login flow) still to come.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorState(message: state.error!, onRetry: notifier.load)
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _ToggleRow(
                      title: 'Keep server awake',
                      subtitle:
                          'Periodically pings the backend so it doesn\'t go idle on the free '
                          'tier and cold-start the next request.',
                      value: state.keepaliveEnabled,
                      onChanged: (value) => _toggle(context, () => notifier.setKeepalive(value)),
                    ),
                    _ToggleRow(
                      title: 'Two-factor authentication',
                      subtitle:
                          'Stores whether 2FA should be required at login. Not enforced yet - '
                          'code generation and delivery aren\'t built, so this is a flag for '
                          'now, not a working feature.',
                      value: state.twoFactorEnabled,
                      onChanged: (value) => _toggle(context, () => notifier.setTwoFactor(value)),
                    ),
                  ],
                ),
    );
  }

  Future<void> _toggle(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      final message =
          (data is Map && data['error'] is String) ? data['error'] as String : "Couldn't save.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
