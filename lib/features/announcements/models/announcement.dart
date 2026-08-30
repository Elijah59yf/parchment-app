/// Mirrors the shape returned by the backend for an announcement row,
/// joined with its author (see announcements.controller.js, every
/// list/get/create/update response nests `author: { id, full_name, role }`).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.sendPush,
    required this.sendEmail,
    required this.createdAt,
    required this.updatedAt,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
  });

  final String id;
  final String title;
  final String body;
  final bool isPinned;
  final bool sendPush;
  final bool sendEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorId;
  final String authorName;
  final String authorRole;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isPinned: json['is_pinned'] as bool? ?? false,
      sendPush: json['send_push'] as bool? ?? false,
      sendEmail: json['send_email'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      authorId: author?['id'] as String? ?? json['author_id'] as String? ?? '',
      authorName: author?['full_name'] as String? ?? 'Unknown',
      authorRole: author?['role'] as String? ?? 'student',
    );
  }

  /// PATCH /announcements/:id responds with `.select('*')` only, no
  /// joined author object (unlike create/list/get, which all join it).
  /// Use this to apply that partial response onto the announcement
  /// already held locally, preserving its author fields rather than
  /// re-parsing raw PATCH JSON with Announcement.fromJson (which would
  /// silently fall back to "Unknown"/"student" for the missing author).
  Announcement copyWith({
    String? title,
    String? body,
    bool? isPinned,
    bool? sendPush,
    bool? sendEmail,
    DateTime? updatedAt,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      isPinned: isPinned ?? this.isPinned,
      sendPush: sendPush ?? this.sendPush,
      sendEmail: sendEmail ?? this.sendEmail,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
    );
  }

  /// Applies a raw PATCH /announcements/:id response (plain columns,
  /// no author join) onto this announcement via copyWith.
  Announcement mergePatchResponse(Map<String, dynamic> json) {
    return copyWith(
      title: json['title'] as String?,
      body: json['body'] as String?,
      isPinned: json['is_pinned'] as bool?,
      sendPush: json['send_push'] as bool?,
      sendEmail: json['send_email'] as bool?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
