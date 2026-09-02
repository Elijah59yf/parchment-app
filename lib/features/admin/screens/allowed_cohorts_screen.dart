import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/allowed_cohort.dart';
import '../models/department.dart';
import '../models/faculty.dart';
import '../providers/allowed_cohorts_provider.dart';
import '../providers/faculty_department_provider.dart';

/// Admin-only. Controls which (year, faculty, department) combinations
/// are allowed to register/log in, plus an optional per-cohort level/
/// semester override on the global session clock.
///
/// Needs faculties+departments loaded for the create dialog's dropdowns,
/// so it watches facultyDepartmentProvider alongside allowedCohortsProvider
/// rather than duplicating that fetch.
class AllowedCohortsScreen extends ConsumerWidget {
  const AllowedCohortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(allowedCohortsProvider);
    final notifier = ref.read(allowedCohortsProvider.notifier);
    final facultyState = ref.watch(facultyDepartmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allowed Cohorts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add cohort',
            onPressed: facultyState.faculties.isEmpty
                ? null
                : () => showDialog(context: context, builder: (_) => const _CohortFormDialog()),
          ),
        ],
      ),
      body: _buildBody(context, state, notifier, facultyState.isLoading),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AllowedCohortsState state,
    AllowedCohortsNotifier notifier,
    bool facultiesLoading,
  ) {
    if (state.isLoading || facultiesLoading) {
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

    if (state.cohorts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 40, color: AppTheme.subtle),
              const SizedBox(height: 12),
              Text('No allowed cohorts yet', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Add one so students in that year/department can register.',
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
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: _facultyGroups(state.cohorts),
      ),
    );
  }

  /// Groups cohorts into Faculty > Department, each level sorted by
  /// its own code (same order as the Faculties & Departments screen),
  /// so departments from different faculties are never shown mixed
  /// together and years are scoped under the department they belong to.
  List<Widget> _facultyGroups(List<AllowedCohort> cohorts) {
    final byFaculty = <String, List<AllowedCohort>>{};
    for (final cohort in cohorts) {
      byFaculty.putIfAbsent(cohort.facultyId, () => []).add(cohort);
    }

    final facultyIds = byFaculty.keys.toList()
      ..sort((a, b) {
        final codeA = byFaculty[a]!.first.faculty?.code ?? a;
        final codeB = byFaculty[b]!.first.faculty?.code ?? b;
        return codeA.compareTo(codeB);
      });

    return [
      for (final facultyId in facultyIds)
        _FacultyGroup(
          facultyId: facultyId,
          faculty: byFaculty[facultyId]!.first.faculty,
          cohorts: byFaculty[facultyId]!,
        ),
    ];
  }
}

/// Top level of the hierarchy: one expansion tile per faculty,
/// containing that faculty's departments (never another faculty's).
class _FacultyGroup extends StatelessWidget {
  const _FacultyGroup({required this.facultyId, required this.faculty, required this.cohorts});

  final String facultyId;
  final Faculty? faculty;
  final List<AllowedCohort> cohorts;

  @override
  Widget build(BuildContext context) {
    final byDepartment = <String, List<AllowedCohort>>{};
    for (final cohort in cohorts) {
      byDepartment.putIfAbsent(cohort.departmentId, () => []).add(cohort);
    }

    final departmentIds = byDepartment.keys.toList()
      ..sort((a, b) {
        final codeA = byDepartment[a]!.first.department?.code ?? a;
        final codeB = byDepartment[b]!.first.department?.code ?? b;
        return codeA.compareTo(codeB);
      });

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          leading: _CodeBadge(code: faculty?.code ?? '?'),
          title: Text(faculty?.name ?? facultyId, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text('${cohorts.length} cohort${cohorts.length == 1 ? '' : 's'}'),
          children: [
            for (final departmentId in departmentIds)
              _DepartmentGroup(
                departmentId: departmentId,
                department: byDepartment[departmentId]!.first.department,
                cohorts: byDepartment[departmentId]!
                  ..sort((a, b) => a.cohortYear.compareTo(b.cohortYear)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Second level: one expansion tile per department, nested under its
/// faculty, containing that department's individual cohort years.
class _DepartmentGroup extends StatelessWidget {
  const _DepartmentGroup({
    required this.departmentId,
    required this.department,
    required this.cohorts,
  });

  final String departmentId;
  final Department? department;
  final List<AllowedCohort> cohorts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
          childrenPadding: EdgeInsets.zero,
          leading: _CodeBadge(code: department?.code ?? '?', small: true),
          title: Text(department?.name ?? departmentId, style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('${cohorts.length} cohort year${cohorts.length == 1 ? '' : 's'}'),
          children: [for (final cohort in cohorts) _CohortYearRow(cohort: cohort)],
        ),
      ),
    );
  }
}

/// Leaf row nested under a _DepartmentGroup - just the year plus its
/// controls. Faculty and department are already shown by the ancestor
/// groups, so this doesn't repeat them.
class _CohortYearRow extends ConsumerWidget {
  const _CohortYearRow({required this.cohort});

  final AllowedCohort cohort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(44, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cohort.cohortYear}', style: Theme.of(context).textTheme.titleMedium),
                if (cohort.hasOverride) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (cohort.levelOverride != null)
                        _OverrideChip(label: 'Level ${cohort.levelOverride}'),
                      if (cohort.semesterOverride != null)
                        _OverrideChip(label: 'Semester ${cohort.semesterOverride}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cohort.isActive ? 'Active' : 'Inactive',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cohort.isActive ? AppTheme.ink : AppTheme.subtle,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Switch(
                value: cohort.isActive,
                onChanged: (value) async {
                  try {
                    await ref.read(allowedCohortsProvider.notifier).setActive(cohort.id, value);
                  } on DioException catch (e) {
                    if (!context.mounted) return;
                    _showError(context, e, "Couldn't update cohort.");
                  }
                },
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == 'override') {
                showDialog(context: context, builder: (_) => _OverrideDialog(cohort: cohort));
              } else if (action == 'delete') {
                _confirmDelete(context, ref, cohort);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'override', child: Text('Clock override')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AllowedCohort cohort) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete cohort?'),
        content: Text(
          '${cohort.department?.name ?? cohort.departmentId} (${cohort.cohortYear}) will no '
          'longer be able to register or log in. This can\'t be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(allowedCohortsProvider.notifier).delete(cohort.id);
    } on DioException catch (e) {
      if (!context.mounted) return;
      _showError(context, e, "Couldn't delete cohort.");
    }
  }
}

/// A code (department, faculty, cohort year) shown in a bordered
/// square rather than a filled circle, matching AppTheme's "square,
/// never a stadium/pill shape" rule. `small` is used for departments
/// nested under a faculty, so they read as one level down.
class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.code, this.small = false});

  final String code;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}

class _OverrideChip extends StatelessWidget {
  const _OverrideChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

void _showError(BuildContext context, DioException e, String fallback) {
  final data = e.response?.data;
  final message = (data is Map && data['error'] is String) ? data['error'] as String : fallback;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _CohortFormDialog extends ConsumerStatefulWidget {
  const _CohortFormDialog();

  @override
  ConsumerState<_CohortFormDialog> createState() => _CohortFormDialogState();
}

class _CohortFormDialogState extends ConsumerState<_CohortFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _yearController =
      TextEditingController(text: DateTime.now().year.toString());
  String? _facultyId;
  String? _departmentId;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _facultyId == null ||
        _departmentId == null ||
        _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final facultyState = ref.read(facultyDepartmentProvider);
    final faculty = facultyState.faculties.where((f) => f.id == _facultyId).firstOrNull;
    final department = facultyState.departments.where((d) => d.id == _departmentId).firstOrNull;

    try {
      await ref.read(allowedCohortsProvider.notifier).create(
            cohortYear: int.parse(_yearController.text.trim()),
            facultyId: _facultyId!,
            departmentId: _departmentId!,
            faculty: faculty,
            department: department,
          );
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _isSaving = false;
        _error = (data is Map && data['error'] is String)
            ? data['error'] as String
            : "Couldn't save cohort.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final facultyState = ref.watch(facultyDepartmentProvider);
    final departmentsForFaculty =
        _facultyId == null ? const <Department>[] : facultyState.departmentsFor(_facultyId!);

    return AlertDialog(
      title: const Text('Add allowed cohort'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _yearController,
              decoration: const InputDecoration(labelText: 'Cohort year'),
              keyboardType: TextInputType.number,
              validator: (value) {
                final year = int.tryParse(value?.trim() ?? '');
                if (year == null || year < 2000 || year > 2100) {
                  return 'Enter a valid year (2000–2100)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _facultyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Faculty'),
              items: [
                for (final f in facultyState.faculties)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text('${f.code} — ${f.name}',
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
              ],
              onChanged: (value) => setState(() {
                _facultyId = value;
                // Department list changes with faculty - last pick may
                // no longer belong to it, so clear it rather than
                // silently submitting a stale department for this faculty.
                _departmentId = null;
              }),
              validator: (value) => value == null ? 'Choose a faculty' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _departmentId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Department',
                helperText: _facultyId == null ? 'Choose a faculty first' : null,
              ),
              items: [
                for (final d in departmentsForFaculty)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.code} — ${d.name}',
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
              ],
              onChanged: _facultyId == null
                  ? null
                  : (value) => setState(() => _departmentId = value),
              validator: (value) => value == null ? 'Choose a department' : null,
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

/// Sets or clears the per-cohort level/semester override. A blank
/// field means "leave unchanged"; the explicit "Clear" buttons are
/// the only way to null a field out and resume tracking the global
/// clock, since a validated numeric field can't itself express null.
class _OverrideDialog extends ConsumerStatefulWidget {
  const _OverrideDialog({required this.cohort});

  final AllowedCohort cohort;

  @override
  ConsumerState<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends ConsumerState<_OverrideDialog> {
  late final _levelController =
      TextEditingController(text: widget.cohort.levelOverride?.toString() ?? '');
  late int? _semester = widget.cohort.semesterOverride;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save({
    bool clearLevel = false,
    bool clearSemester = false,
  }) async {
    if (_isSaving) return;

    int? level;
    if (!clearLevel && _levelController.text.trim().isNotEmpty) {
      level = int.tryParse(_levelController.text.trim());
      if (level == null || level < 100 || level % 100 != 0) {
        setState(() => _error = 'Level must be a multiple of 100 (e.g. 100, 200, 300)');
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(allowedCohortsProvider.notifier).setOverride(
            widget.cohort.id,
            levelOverride: level,
            clearLevelOverride: clearLevel,
            semesterOverride: clearSemester ? null : _semester,
            clearSemesterOverride: clearSemester,
          );
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _isSaving = false;
        _error = (data is Map && data['error'] is String)
            ? data['error'] as String
            : "Couldn't save override.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clock override'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pins this cohort\'s level/semester regardless of the global '
            'session clock. Leave blank to track the clock normally.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _levelController,
                  decoration: const InputDecoration(labelText: 'Level override'),
                  keyboardType: TextInputType.number,
                ),
              ),
              if (widget.cohort.levelOverride != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear level override',
                  onPressed: _isSaving ? null : () => _save(clearLevel: true),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _semester,
                  decoration: const InputDecoration(labelText: 'Semester override'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Semester 1')),
                    DropdownMenuItem(value: 2, child: Text('Semester 2')),
                  ],
                  onChanged: (value) => setState(() => _semester = value),
                ),
              ),
              if (widget.cohort.semesterOverride != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear semester override',
                  onPressed: _isSaving ? null : () => _save(clearSemester: true),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
