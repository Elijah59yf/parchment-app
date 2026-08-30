import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/role_badge.dart';
import '../models/managed_user.dart';
import '../providers/users_list_provider.dart';
import 'edit_user_screen.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String? _roleFilter;
  String _searchQuery = '';

  List<ManagedUser> _applySearch(List<ManagedUser> users) {
    if (_searchQuery.trim().isEmpty) return users;
    final query = _searchQuery.trim().toLowerCase();
    return users
        .where((u) =>
            u.fullName.toLowerCase().contains(query) ||
            u.matricNumber.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersListProvider);
    final filtered = _applySearch(state.users);

    return Scaffold(
      appBar: AppBar(title: const Text('User management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search by name or matric number',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _roleFilter == null,
                    onTap: () {
                      setState(() => _roleFilter = null);
                      ref.read(usersListProvider.notifier).load();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Admin',
                    selected: _roleFilter == 'admin',
                    onTap: () {
                      setState(() => _roleFilter = 'admin');
                      ref.read(usersListProvider.notifier).load(role: 'admin');
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Rep',
                    selected: _roleFilter == 'rep',
                    onTap: () {
                      setState(() => _roleFilter = 'rep');
                      ref.read(usersListProvider.notifier).load(role: 'rep');
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Student',
                    selected: _roleFilter == 'student',
                    onTap: () {
                      setState(() => _roleFilter = 'student');
                      ref
                          .read(usersListProvider.notifier)
                          .load(role: 'student');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildList(state, filtered)),
        ],
      ),
    );
  }

  Widget _buildList(UsersListState state, List<ManagedUser> filtered) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(usersListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No users found' : 'No matches',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(usersListProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = filtered[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                RoleBadge(role: user.role),
                if (!user.isActive) ...[
                  const SizedBox(width: 6),
                  Text(
                    'INACTIVE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
            subtitle: Text('${user.matricNumber} \u2022 ${user.email}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditUserScreen(user: user),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Deliberately not Material's ChoiceChip: it colors its selected
    // state from ColorScheme.secondaryContainer, which app_theme.dart
    // never sets explicitly, so that falls back to Flutter's baseline
    // default, which isn't grayscale. Building this by hand keeps the
    // fill/outline language consistent with RoleBadge and everything
    // else, with zero risk of an unset theme field leaking a color.
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
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
