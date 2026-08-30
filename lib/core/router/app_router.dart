import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/announcements/screens/feed_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authStatusProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
    ],
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/splash';

      // Still checking stored session; stay on splash, don't redirect yet
      if (authStatus == AuthStatus.unknown) {
        return onSplash ? null : '/splash';
      }

      final isAuthenticated = authStatus == AuthStatus.authenticated;

      if (!isAuthenticated && !loggingIn) return '/login';
      if (isAuthenticated && (loggingIn || onSplash)) return '/feed';
      if (!isAuthenticated && onSplash) return '/login';

      return null;
    },
  );
});
