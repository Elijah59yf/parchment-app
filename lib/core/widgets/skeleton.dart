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
  const SkeletonRow({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.hasSubtitle = true,
  });

  /// False for ListTile-style rows with no leading badge at all (e.g.
  /// User Management, which is a plain ListTile - a placeholder badge
  /// there would visually pop into nothing once real content loads).
  final bool hasLeading;
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
          if (hasLeading) ...[
            Skeleton(width: 40, height: 40, borderRadius: BorderRadius.circular(AppTheme.radius)),
            const SizedBox(width: 14),
          ],
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

/// Matches AnnouncementCard's shape - title, a few lines of body
/// preview, then a footer line (small author badge + date) - entirely
/// different proportions from SkeletonRow, so it's its own widget
/// rather than a variant.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton.expand(height: 18),
            const SizedBox(height: 10),
            const Skeleton.expand(height: 14),
            const SizedBox(height: 6),
            const Skeleton.expand(height: 14),
            const SizedBox(height: 6),
            Skeleton(width: MediaQuery.of(context).size.width * 0.5, height: 14),
            const SizedBox(height: 14),
            Row(
              children: [
                Skeleton(width: 90, height: 12, borderRadius: BorderRadius.circular(6)),
                const SizedBox(width: 8),
                Skeleton(width: 50, height: 12, borderRadius: BorderRadius.circular(6)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A handful of SkeletonRows stacked - the usual way this gets used,
/// since a loading list is never just one row.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 5,
    this.hasLeading = true,
    this.hasTrailing = false,
  });

  final int count;
  final bool hasLeading;
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          SkeletonRow(hasLeading: hasLeading, hasTrailing: hasTrailing),
      ],
    );
  }
}

/// A handful of SkeletonCards stacked, spaced the same way Feed/My
/// Announcements space their real AnnouncementCards.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          const SkeletonCard(),
        ],
      ],
    );
  }
}
