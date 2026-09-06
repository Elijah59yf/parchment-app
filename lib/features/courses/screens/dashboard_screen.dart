import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/course.dart';
import '../providers/my_courses_provider.dart';

/// The Dashboard tab (index 0, visible to every role). Right now this
/// is entirely the student's own course list - core courses (always
/// present, no action) plus electives (one unified list, each row's
/// own switch registers/drops it). Every role sees this the same way
/// for now, since admin/rep accounts currently still carry real
/// department/cohort data just like a student (see PLAN.md's "admin
/// as student for now" note) - once non-student admin accounts exist,
/// this needs a guard for callers with no cohort data at all.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCoursesProvider);
    final notifier = ref.read(myCoursesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorState(message: state.error!, onRetry: notifier.load)
              : RefreshIndicator(
                  onRefresh: notifier.load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (state.level != null && state.semester != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                          child: Text(
                            'Level ${state.level} \u00b7 Semester ${state.semester}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.muted),
                          ),
                        ),
                      _SectionHeader(title: 'Core courses'),
                      if (state.core.isEmpty)
                        const _EmptyRow(text: 'No core courses set up for this semester yet.')
                      else
                        for (final course in state.core) _CourseRow(course: course),
                      _SectionHeader(title: 'Electives'),
                      if (state.myElectives.isEmpty && state.availableElectives.isEmpty)
                        const _EmptyRow(text: 'No electives available this semester.')
                      else ...[
                        for (final course in state.myElectives)
                          _CourseRow(
                            course: course,
                            isRegistered: true,
                            onChanged: (_) => _drop(context, notifier, course),
                          ),
                        for (final course in state.availableElectives)
                          _CourseRow(
                            course: course,
                            isRegistered: false,
                            onChanged: (_) => _register(context, notifier, course),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Future<void> _register(
    BuildContext context,
    MyCoursesNotifier notifier,
    Course course,
  ) async {
    try {
      await notifier.register(course);
    } catch (message) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$message')));
    }
  }

  Future<void> _drop(
    BuildContext context,
    MyCoursesNotifier notifier,
    Course course,
  ) async {
    try {
      await notifier.unregister(course);
    } catch (message) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$message')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppTheme.muted, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    this.isRegistered,
    this.onChanged,
  });

  final Course course;

  /// Null for core courses - there's nothing to toggle, they're
  /// mandatory. Non-null for electives, reflecting whether this
  /// particular row is in myElectives or availableElectives.
  final bool? isRegistered;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _CodeBadge(code: course.code),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (course.creditUnits != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${course.creditUnits} unit${course.creditUnits == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (isRegistered != null && onChanged != null)
            Switch(value: isRegistered!, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A course code shown in a bordered square rather than a filled
/// circle, matching AppTheme's "square, never a stadium/pill shape"
/// rule - same treatment as the admin screens' department/faculty
/// badges.
class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        code,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
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
