import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/announcements/screens/feed_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../shell/app_shell.dart';
import '../widgets/coming_soon_screen.dart';

/// Branch order here MUST match _allDestinations in app_shell.dart —
/// index 0 is Dashboard, 1 is Feed, and so on through Admin at 6.
/// Every branch is always present in the router regardless of role;
/// AppShell only controls which ones are *visible* as nav items. This
/// is required by StatefulShellRoute (branches are static), and it
/// also means each tab keeps its own independent navigation stack.
final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authStatusProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/materials',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Materials',
                  icon: Icons.folder_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/polls',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Polls',
                  icon: Icons.poll_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/manage',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Manage',
                  icon: Icons.dashboard_customize_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => const ComingSoonScreen(
                  title: 'Admin',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
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
      if (isAuthenticated && (loggingIn || onSplash)) return '/dashboard';
      if (!isAuthenticated && onSplash) return '/login';

      return null;
    },
  );
});
