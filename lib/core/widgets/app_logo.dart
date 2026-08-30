import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// The Parchment brand mark: scroll glyph + wordmark, top-anchored.
///
/// Replaces the old floating `Icons.description_outlined` on auth
/// screens; that was a generic Material stock icon standing in for a
/// brand that already has a real mark. This renders the actual traced
/// scroll SVG (assets/images/logo.svg), tinted to the current
/// monochrome ink color via ColorFilter; never edit the SVG's own
/// fill values to recolor it, tint here instead.
///
/// Sized small (28px by default) and left-aligned as a proper header
/// lockup, not a large centered hero icon.
class AppLogoLockup extends StatelessWidget {
  const AppLogoLockup({
    super.key,
    this.size = 34,
    this.alignment = MainAxisAlignment.start,
  });

  final double size;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        SvgPicture.asset(
          'assets/images/logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(AppTheme.ink, BlendMode.srcIn),
        ),
        SizedBox(width: size * 0.32),
        Text(
          'Parchment',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: size * 0.62,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}
