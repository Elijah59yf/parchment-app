import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/push/push_notification_service.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: ParchmentApp()));
}

class ParchmentApp extends ConsumerWidget {
  const ParchmentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Fires once on first build, then again only when auth status
    // actually changes value (ref.listen semantics) - so the token
    // gets (re-)registered right after login, not on every rebuild.
    ref.listen<AuthStatus>(authStatusProvider, (previous, next) async {
      if (next == AuthStatus.authenticated) {
        final pushService = ref.read(pushNotificationServiceProvider);
        await pushService.init();
        await pushService.registerToken();
      }
    });

    return MaterialApp.router(
      title: 'Parchment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
