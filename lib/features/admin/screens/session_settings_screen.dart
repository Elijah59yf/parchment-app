import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/faculty_department_provider.dart';
import '../providers/session_clock_provider.dart';

/// Admin-only. The global academic clock: current session (e.g.
/// "2025/2026") and semester (1 or 2), which every allowed cohort's
/// level/semester is computed from unless it has its own override
/// (set on the Allowed Cohorts screen).
///
/// Saving applies immediately - there's no dry run - so after a
/// successful save this shows exactly which cohorts moved, sourced
/// from the same response the backend already computes.
class SessionSettingsScreen extends ConsumerStatefulWidget {
  const SessionSettingsScreen({super.key});

  @override
  ConsumerState<SessionSettingsScreen> createState() => _SessionSettingsScreenState();
}

class _SessionSettingsScreenState extends ConsumerState<SessionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sessionController;
  int? _semester;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _sessionController = TextEditingController();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  /// The form starts empty until the clock has loaded once, then seeds
  /// itself from whatever's currently set. Only runs once - after that
  /// the fields are the user's to edit, not something to keep
  /// overwriting on every rebuild.
  void _seedFromState(SessionClockState state) {
    if (_initialized || state.isLoading) return;
    _initialized = true;
    _sessionController.text = state.currentSession ?? '';
    _semester = state.currentSemester;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionClockProvider);
    _seedFromState(state);

    return Scaffold(
      appBar: AppBar(title: const Text('Session Settings')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'The academic year this clock is tracking, e.g. "2025/2026".',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sessionController,
                      decoration: const InputDecoration(
                        labelText: 'Session',
                        hintText: '2025/2026',
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (!RegExp(r'^\d{4}/\d{4}$').hasMatch(v)) {
                          return 'Use the format YYYY/YYYY, e.g. 2025/2026';
                        }
                        final start = int.parse(v.substring(0, 4));
                        final end = int.parse(v.substring(5, 9));
                        if (end != start + 1) return 'Second year should follow the first';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Semester', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Semester 1')),
                        ButtonSegment(value: 2, label: Text('Semester 2')),
                      ],
                      selected: {if (_semester != null) _semester!},
                      emptySelectionAllowed: true,
                      onSelectionChanged: (selected) {
                        setState(() => _semester = selected.isEmpty ? null : selected.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every allowed cohort without its own override moves to this level/semester '
                      'immediately on save.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.subtle),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: state.isSaving ? null : _submit,
                      child: state.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _submit() async {
    if (_semester == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a semester.')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = _sessionController.text.trim();
    final semester = _semester!;

    try {
      final changes =
          await ref.read(sessionClockProvider.notifier).update(
                currentSession: session,
                currentSemester: semester,
              );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _ChangesDialog(changes: changes, session: session, semester: semester),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message =
          (data is Map && data['error'] is String) ? data['error'] as String : "Couldn't save.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

/// Summarizes what the save just did - either confirms nothing moved,
/// or lists every cohort whose level/semester changed, grouped by
/// department so it reads the same way Allowed Cohorts does.
class _ChangesDialog extends ConsumerWidget {
  const _ChangesDialog({required this.changes, required this.session, required this.semester});

  final List<CohortSpaceChange> changes;
  final String session;
  final int semester;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(facultyDepartmentProvider).departments;
    String departmentName(String id) {
      for (final d in departments) {
        if (d.id == id) return d.name;
      }
      return id;
    }

    return AlertDialog(
      title: Text('Clock set to $session, semester $semester'),
      content: SizedBox(
        width: double.maxFinite,
        child: changes.isEmpty
            ? const Text('No cohorts moved - every level/semester stayed the same.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${changes.length} cohort${changes.length == 1 ? '' : 's'} moved:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final change in changes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  TextSpan(
                                    text: '${departmentName(change.departmentId)} '
                                        '${change.cohortYear}: ',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: change.fromLevel == null
                                        ? 'now L${change.toLevel} S${change.toSemester}'
                                        : 'L${change.fromLevel} S${change.fromSemester} '
                                            '\u2192 L${change.toLevel} S${change.toSemester}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}
