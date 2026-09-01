import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/department.dart';
import '../models/faculty.dart';
import '../providers/faculty_department_provider.dart';

/// Admin-only. Faculties list as expansion tiles; each expands to its
/// departments. Both levels get the same add/edit/delete affordances -
/// a faculty-level "+" adds a department pre-scoped to that faculty,
/// while the top app-bar "+" adds a faculty.
class FacultyDepartmentScreen extends ConsumerWidget {
  const FacultyDepartmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(facultyDepartmentProvider);
    final notifier = ref.read(facultyDepartmentProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculties & Departments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add faculty',
            onPressed: () => _showFacultyDialog(context, ref),
          ),
        ],
      ),
      body: _buildBody(context, ref, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    FacultyDepartmentState state,
    FacultyDepartmentNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: notifier.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (state.faculties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_outlined, size: 40, color: AppTheme.subtle),
              const SizedBox(height: 12),
              Text('No faculties yet', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Add one to start building out departments and cohorts.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.faculties.length,
        itemBuilder: (context, index) {
          final faculty = state.faculties[index];
          final departments = state.departmentsFor(faculty.id);
          return _FacultyTile(faculty: faculty, departments: departments);
        },
      ),
    );
  }

  static Future<void> _showFacultyDialog(BuildContext context, WidgetRef ref) {
    return showDialog(
      context: context,
      builder: (_) => const _FacultyFormDialog(),
    );
  }
}

class _FacultyTile extends ConsumerWidget {
  const _FacultyTile({required this.faculty, required this.departments});

  final Faculty faculty;
  final List<Department> departments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.ink,
          child: Text(faculty.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        title: Text(faculty.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${departments.length} department${departments.length == 1 ? '' : 's'}'),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (action == 'edit') {
              showDialog(context: context, builder: (_) => _FacultyFormDialog(faculty: faculty));
            } else if (action == 'delete') {
              _confirmDeleteFaculty(context, ref, faculty);
            } else if (action == 'add_department') {
              showDialog(
                context: context,
                builder: (_) => _DepartmentFormDialog(initialFacultyId: faculty.id),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'add_department', child: Text('Add department')),
            PopupMenuItem(value: 'edit', child: Text('Edit faculty')),
            PopupMenuItem(value: 'delete', child: Text('Delete faculty')),
          ],
        ),
        children: [
          if (departments.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No departments yet.'),
            )
          else
            for (final department in departments)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 8),
                title: Text(department.name),
                subtitle: Text('Code ${department.code}'),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    if (action == 'edit') {
                      showDialog(
                        context: context,
                        builder: (_) => _DepartmentFormDialog(department: department),
                      );
                    } else if (action == 'delete') {
                      _confirmDeleteDepartment(context, ref, department);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFaculty(BuildContext context, WidgetRef ref, Faculty faculty) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete faculty?'),
        content: Text(
          'This also deletes every department under ${faculty.name}, and any allowed '
          'cohorts that reference it. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(facultyDepartmentProvider.notifier).deleteFaculty(faculty.id);
    } on DioException catch (e) {
      if (!context.mounted) return;
      _showError(context, e, "Couldn't delete faculty.");
    }
  }

  Future<void> _confirmDeleteDepartment(BuildContext context, WidgetRef ref, Department department) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text('This deletes ${department.name} and any allowed cohorts under it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(facultyDepartmentProvider.notifier).deleteDepartment(department.id);
    } on DioException catch (e) {
      if (!context.mounted) return;
      _showError(context, e, "Couldn't delete department.");
    }
  }
}

void _showError(BuildContext context, DioException e, String fallback) {
  final data = e.response?.data;
  final message = (data is Map && data['error'] is String) ? data['error'] as String : fallback;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Shared code/name validation matching validators.js createFacultySchema
/// /createDepartmentSchema exactly: 2-digit code, 2-150 char name.
class _FacultyFormDialog extends ConsumerStatefulWidget {
  const _FacultyFormDialog({this.faculty});

  final Faculty? faculty;

  @override
  ConsumerState<_FacultyFormDialog> createState() => _FacultyFormDialogState();
}

class _FacultyFormDialogState extends ConsumerState<_FacultyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(text: widget.faculty?.code);
  late final _nameController = TextEditingController(text: widget.faculty?.name);
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.faculty != null;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final notifier = ref.read(facultyDepartmentProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateFaculty(
          widget.faculty!.id,
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
        );
      } else {
        await notifier.createFaculty(
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _isSaving = false;
        _error = (data is Map && data['error'] is String)
            ? data['error'] as String
            : "Couldn't save faculty.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit faculty' : 'Add faculty'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Code (2 digits)'),
              keyboardType: TextInputType.number,
              maxLength: 2,
              validator: (value) {
                if (value == null || !RegExp(r'^\d{2}$').hasMatch(value.trim())) {
                  return 'Must be exactly 2 digits';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length < 2) return 'Name is too short';
                if (trimmed.length > 150) return 'Name is too long';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.paper),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _DepartmentFormDialog extends ConsumerStatefulWidget {
  const _DepartmentFormDialog({this.department, this.initialFacultyId});

  final Department? department;
  final String? initialFacultyId;

  @override
  ConsumerState<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends ConsumerState<_DepartmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(text: widget.department?.code);
  late final _nameController = TextEditingController(text: widget.department?.name);
  late String? _facultyId = widget.department?.facultyId ?? widget.initialFacultyId;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.department != null;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _facultyId == null || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final notifier = ref.read(facultyDepartmentProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateDepartment(
          widget.department!.id,
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          facultyId: _facultyId!,
        );
      } else {
        await notifier.createDepartment(
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          facultyId: _facultyId!,
        );
      }
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _isSaving = false;
        _error = (data is Map && data['error'] is String)
            ? data['error'] as String
            : "Couldn't save department.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final faculties = ref.watch(facultyDepartmentProvider).faculties;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit department' : 'Add department'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _facultyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Faculty'),
              items: [
                for (final f in faculties)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      '${f.code} — ${f.name}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _facultyId = value),
              validator: (value) => value == null ? 'Choose a faculty' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Code (2 digits)'),
              keyboardType: TextInputType.number,
              maxLength: 2,
              validator: (value) {
                if (value == null || !RegExp(r'^\d{2}$').hasMatch(value.trim())) {
                  return 'Must be exactly 2 digits';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length < 2) return 'Name is too short';
                if (trimmed.length > 150) return 'Name is too long';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.paper),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
