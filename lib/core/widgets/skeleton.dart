import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Base skeleton box: a gray rounded rect with a lighter sweep passing
/// over it on a loop. Kept strictly grayscale (AppTheme.border as the
/// resting shade, AppTheme.paper as the sweep highlight) so it holds
/// the same monochrome rule as everything else - no hue anywhere.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  /// A skeleton that fills whatever width its parent gives it (e.g. a
  /// title-line placeholder inside an Expanded) rather than a fixed
  /// pixel width.
  const Skeleton.expand({super.key, required this.height, this.borderRadius})
      : width = double.infinity;

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.border,
      highlightColor: AppTheme.paper,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Matches the badge + title + subtitle (+ optional trailing control)
/// row shape used across Courses, Allowed Cohorts, Faculty &
/// Departments, and User Management - one shape covers the loading
/// state for all of them rather than a bespoke skeleton per screen.
/// Same padding/border as the real rows so the transition from
/// loading to loaded doesn't visibly jump.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.hasTrailing = false, this.hasSubtitle = true});

  final bool hasTrailing;
  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Skeleton(width: 40, height: 40, borderRadius: BorderRadius.circular(AppTheme.radius)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton.expand(height: 16),
                if (hasSubtitle) ...[
                  const SizedBox(height: 8),
                  Skeleton(width: MediaQuery.of(context).size.width * 0.35, height: 12),
                ],
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            Skeleton(width: 40, height: 24, borderRadius: BorderRadius.circular(12)),
          ],
        ],
      ),
    );
  }
}

/// A handful of SkeletonRows stacked - the usual way this gets used,
/// since a loading list is never just one row.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.hasTrailing = false});

  final int count;
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) SkeletonRow(hasTrailing: hasTrailing),
      ],
    );
  }
}
