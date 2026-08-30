import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/announcement.dart';
import '../providers/announcements_provider.dart';

/// Compose screen for reps/admins. POST /announcements, or PATCH
/// /announcements/:id when `existing` is provided (edit mode).
///
/// Matches the backend's createAnnouncementSchema: title, body (both
/// required), plus isPinned/sendPush/sendEmail toggles matching the
/// controller's own field names. Note: the backend itself defaults
/// sendEmail to true when the field is omitted, but this screen always
/// sends an explicit value and defaults its own UI toggle to false for
/// new posts. A deliberate product choice, not an oversight, so email
/// is opt-in per post rather than sent automatically for everything.
///
/// On success, updates announcementsProvider's in-memory list directly
/// (prepend for create, in-place replace for edit) rather than
/// re-fetching the whole feed, avoiding a network round trip just to
/// see the result of your own action.
class ComposeAnnouncementScreen extends ConsumerStatefulWidget {
  const ComposeAnnouncementScreen({super.key, this.existing});

  /// When provided, the screen opens in edit mode: fields pre-filled,
  /// submit calls PATCH instead of POST.
  final Announcement? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<ComposeAnnouncementScreen> createState() =>
      _ComposeAnnouncementScreenState();
}

class _ComposeAnnouncementScreenState
    extends ConsumerState<ComposeAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  late bool _isPinned;
  late bool _sendPush;
  late bool _sendEmail;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _bodyController = TextEditingController(text: existing?.body ?? '');
    _isPinned = existing?.isPinned ?? false;
    _sendPush = existing?.sendPush ?? false;
    // New posts default email off (see class doc); editing an existing
    // post keeps whatever it was already set to.
    _sendEmail = existing?.sendEmail ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a title';
    return null;
  }

  String? _validateBody(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter the announcement body';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);

    final apiClient = ref.read(apiClientProvider);
    final notifier = ref.read(announcementsProvider.notifier);
    final existing = widget.existing;

    try {
      if (existing == null) {
        final response = await apiClient.dio.post(
          '/announcements',
          data: {
            'title': _titleController.text.trim(),
            'body': _bodyController.text.trim(),
            'isPinned': _isPinned,
            'sendPush': _sendPush,
            'sendEmail': _sendEmail,
          },
        );

        final data = response.data as Map<String, dynamic>;
        final announcement = Announcement.fromJson(
          data['announcement'] as Map<String, dynamic>,
        );
        notifier.prependPosted(announcement);
      } else {
        final response = await apiClient.dio.patch(
          '/announcements/${existing.id}',
          data: {
            'title': _titleController.text.trim(),
            'body': _bodyController.text.trim(),
            'isPinned': _isPinned,
            'sendPush': _sendPush,
            'sendEmail': _sendEmail,
          },
        );

        // PATCH responds with plain columns, no joined author; merge
        // onto the announcement we already have rather than re-parsing
        // raw JSON (see Announcement.mergePatchResponse doc).
        final data = response.data as Map<String, dynamic>;
        final updated = existing.mergePatchResponse(
          data['announcement'] as Map<String, dynamic>,
        );
        notifier.updateLocal(updated);

        if (!mounted) return;
        Navigator.of(context).pop(updated);
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      _showErrorDialog(_dioErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Couldn\'t reach the server. Check your connection and try again '
          '(the backend may be waking up from idle, so this can take a moment).';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Couldn\'t post'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit post' : 'New post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                  validator: _validateTitle,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Body',
                    alignLabelWithHint: true,
                  ),
                  validator: _validateBody,
                ),
                const SizedBox(height: 24),
                Text(
                  'Options',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                _OptionSwitch(
                  title: 'Pin to top',
                  subtitle: 'Keeps this above other announcements',
                  value: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v),
                ),
                _OptionSwitch(
                  title: 'Send push notification',
                  subtitle: 'For anything time-sensitive or urgent',
                  value: _sendPush,
                  onChanged: (v) => setState(() => _sendPush = v),
                ),
                _OptionSwitch(
                  title: 'Send email',
                  subtitle: 'Off by default \u2014 turn on for anything worth an inbox notification',
                  value: _sendEmail,
                  onChanged: (v) => setState(() => _sendEmail = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
