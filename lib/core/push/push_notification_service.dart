import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/announcements/models/announcement.dart';
import '../../features/announcements/screens/announcement_detail_screen.dart';
import '../../features/auth/providers/auth_provider.dart' show apiClientProvider;
import '../router/app_router.dart';

/// Must be a top-level (or static) function — FCM runs this in a
/// separate background isolate when a data/notification message
/// arrives while the app is backgrounded or terminated, so it can't
/// close over any app state. Re-initializing Firebase here is
/// required for that same reason: this isolate hasn't run main().
///
/// This is intentionally a no-op beyond that init. Anything it needs
/// to *do* with the message (deep-link, update local state) happens
/// later when the user actually taps it, via onMessageOpenedApp /
/// getInitialMessage in PushNotificationService — not here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

const String _androidChannelId = 'parchment_announcements';
const String _androidChannelName = 'Announcements';

/// Owns the whole push notification lifecycle:
///  - permission request
///  - FCM token registration with the backend (PUT /users/me/fcm-token)
///    on first grant and again on every token rotation
///  - showing a heads-up notification when a message arrives while
///    the app is in the foreground (FCM only auto-shows one for
///    background/terminated; foreground delivery is silent otherwise)
///  - deep-linking to the relevant AnnouncementDetailScreen when a
///    notification is tapped, whether that's a background->foreground
///    resume (onMessageOpenedApp) or a cold start (getInitialMessage)
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Only Android/iOS have a real push story here; desktop targets in
  /// this project (linux/macos/windows) skip this entirely rather than
  /// fail trying to initialize Firebase without platform config for them.
  bool get _supportsPush =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() async {
    if (_initialized || !_supportsPush) return;
    _initialized = true;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();

    final settings = await FirebaseMessaging.instance.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return;

    // Foreground: FCM delivers silently, so show it ourselves.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App was backgrounded (not terminated) and the user tapped the
    // system notification to bring it back to the foreground.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // App was terminated and launched fresh by tapping the
    // notification - only available once, right after launch.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Router/first frame may not be ready yet on a cold start; defer
      // to the next frame so rootNavigatorKey has something to push to.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessageTap(initialMessage);
      });
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final announcementId = response.payload;
        if (announcementId != null) {
          _openAnnouncement(announcementId);
        }
      },
    );

    // Android 8+ requires a channel to be registered before any
    // notification using it can be shown.
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'New announcement alerts',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Carried through to onDidReceiveNotificationResponse if the
      // user taps this local notification.
      payload: message.data['announcementId'] as String?,
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    if (message.data['type'] != 'announcement') return;
    final announcementId = message.data['announcementId'] as String?;
    if (announcementId != null) {
      _openAnnouncement(announcementId);
    }
  }

  /// Fetches the full announcement (a push payload only ever carries
  /// its id) and pushes the same detail screen every in-app tap uses,
  /// via the root navigator - this can fire before any particular
  /// screen's own BuildContext exists (cold start), so it can't rely
  /// on one being passed in.
  Future<void> _openAnnouncement(String announcementId) async {
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) return;

    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/announcements/$announcementId');
      final data = response.data as Map<String, dynamic>;
      final announcement =
          Announcement.fromJson(data['announcement'] as Map<String, dynamic>);

      navigatorState.push(
        MaterialPageRoute(
          builder: (_) => AnnouncementDetailScreen(announcement: announcement),
        ),
      );
    } on DioException {
      // Announcement may have been deleted since the push was sent, or
      // the request failed - either way, silently drop the deep link
      // rather than showing an error for something the user didn't
      // explicitly ask for in the moment.
    }
  }

  /// Registers the current FCM token with the backend, and keeps it
  /// current by re-registering whenever FCM rotates it. Call once the
  /// user is authenticated (a registration call while logged out would
  /// just 401 - there's no user row yet to attach the token to).
  Future<void> registerToken() async {
    if (!_supportsPush) return;

    final apiClient = _ref.read(apiClientProvider);

    Future<void> register(String? token) async {
      if (token == null) return;
      try {
        await apiClient.dio.put('/users/me/fcm-token', data: {'fcmToken': token});
      } on DioException {
        // Best-effort: a failed registration just means this device
        // won't get pushes until the next successful attempt (app
        // relaunch, token refresh, etc.) - not worth surfacing to the
        // user over.
      }
    }

    await register(await FirebaseMessaging.instance.getToken());
    FirebaseMessaging.instance.onTokenRefresh.listen(register);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
