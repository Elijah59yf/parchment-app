import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/current_user_provider.dart';
import '../models/managed_user.dart';
import '../providers/users_list_provider.dart';

/// Role and status editor for one user. Mirrors two protections the
/// backend already enforces (updateUserRole / updateUserStatus): an
/// admin can't demote or deactivate their own account. Rather than
/// let the user attempt that and eat a 400, this screen disables those
/// specific controls up front when editing your own row; the
/// server-side check stays authoritative either way.
class EditUserScreen extends ConsumerStatefulWidget {
  const EditUserScreen({super.key, required this.user});

  final ManagedUser user;

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  late String _role;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _isActive = widget.user.isActive;
  }

  bool get _roleChanged => _role != widget.user.role;
  bool get _statusChanged => _isActive != widget.user.isActive;
  bool get _hasChanges => _roleChanged || _statusChanged;

  Future<void> _save(bool isSelf) async {
    if (!_hasChanges || _isSaving) return;
    setState(() => _isSaving = true);

    final apiClient = ref.read(apiClientProvider);
    var updated = widget.user;

    try {
      if (_roleChanged) {
        final response = await apiClient.dio.patch(
          '/users/${widget.user.id}/role',
          data: {'role': _role},
        );
        final data = response.data as Map<String, dynamic>;
        updated = ManagedUser.fromJson(data['user'] as Map<String, dynamic>);
      }

      if (_statusChanged) {
        final response = await apiClient.dio.patch(
          '/users/${widget.user.id}/status',
          data: {'isActive': _isActive},
        );
        final data = response.data as Map<String, dynamic>;
        updated = ManagedUser.fromJson(data['user'] as Map<String, dynamic>);
      }

      ref.read(usersListProvider.notifier).updateLocal(updated);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final data = e.response?.data;
      final message = (data is Map && data['error'] is String)
          ? data['error'] as String
          : 'Couldn\'t save changes. Please try again.';
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (me) => _buildScaffold(context, isSelf: me.id == widget.user.id),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Couldn\'t load your profile.')),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool isSelf}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.fullName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed:
                    _hasChanges && !_isSaving ? () => _save(isSelf) : null,
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.user.matricNumber} \u2022 ${widget.user.email}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 28),
              Text('Role', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              if (isSelf)
                Text(
                  'You can\'t change your own role.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    _RoleOption(
                      label: 'Admin',
                      value: 'admin',
                      groupValue: _role,
                      onSelected: (v) => setState(() => _role = v),
                    ),
                    _RoleOption(
                      label: 'Rep',
                      value: 'rep',
                      groupValue: _role,
                      onSelected: (v) => setState(() => _role = v),
                    ),
                    _RoleOption(
                      label: 'Student',
                      value: 'student',
                      groupValue: _role,
                      onSelected: (v) => setState(() => _role = v),
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              Text('Status', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              if (isSelf)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'You can\'t deactivate your own account.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isActive
                            ? 'Active \u2014 can log in normally'
                            : 'Inactive \u2014 blocked from logging in',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.ink : Colors.transparent,
          border: Border.all(
            color: selected ? AppTheme.ink : AppTheme.border,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.paper : AppTheme.ink,
          ),
        ),
      ),
    );
  }
}
