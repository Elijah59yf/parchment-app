import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Purely presentational. Actual auth-check logic lives in
/// authStatusProvider and the router's redirect callback. This screen
/// just needs to exist long enough to show the logo while that check
/// resolves (which is near-instant, reading local secure storage).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.accent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/parchment_logo_transparent.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const Text(
              'Parchment',
              style: TextStyle(
                color: Color(0xFFFAFAF8),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
