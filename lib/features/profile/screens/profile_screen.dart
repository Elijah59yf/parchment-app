import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/current_user_provider.dart';

/// Account info + logout. This is the new home for logout (moved off
/// the feed app bar now that a dedicated tab exists for it — avoids
/// having two places in the app that do the same thing).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: currentUser.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _friendlyError(error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(currentUserProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (user) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.surface,
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user.fullName,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _roleLabel(user.role),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
              ),
            ),
            const SizedBox(height: 32),
            _InfoRow(label: 'Matric number', value: user.matricNumber),
            _InfoRow(label: 'Email', value: user.email),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'rep':
        return 'Class rep';
      default:
        return 'Student';
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You\'ll need your matric number and password to log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStatusProvider.notifier).logout();
      // Router redirect sends the user to /login once state flips.
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Turns whatever currentUserProvider's Future threw into something a
/// user should actually see - never the raw exception. A DioException
/// (like a DNS/connection failure) previously rendered as a full
/// SocketException stack trace directly on screen; this maps the
/// common cases to plain language and falls back to a generic message
/// for anything else, so nothing internal ever leaks into the UI.
String _friendlyError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return "Couldn't connect. Check your internet connection and try again.";
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond. Try again.';
      default:
        final data = error.response?.data;
        if (data is Map && data['error'] is String) {
          return data['error'] as String;
        }
        return "Couldn't load your profile.";
    }
  }
  return "Couldn't load your profile.";
}
