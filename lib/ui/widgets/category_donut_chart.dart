import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/spending_analytics.dart';
import '../../utils/analytics_format.dart';

const categoryChartColors = [
  Color(0xff237a50),
  Color(0xff456ac9),
  Color(0xffb46620),
  Color(0xff9657b2),
  Color(0xffc24667),
  Color(0xff65747c),
];

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({required this.data, super.key});
  final SpendingAnalytics data;

  @override
  Widget build(BuildContext context) {
    final fractions = data.categories
        .map((category) => category.fraction)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Spending by category',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              'Category spending donut. Total ${formatAnalyticsVnd(data.totalCents)}',
          child: SizedBox(
            height: 220,
            child: TweenAnimationBuilder<double>(
              key: ObjectKey(data),
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => CustomPaint(
                painter: CategoryDonutPainter(
                  fractions: fractions,
                  colors: categoryChartColors,
                  progress: progress,
                  trackColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Total: ${compactAnalyticsVnd(data.totalCents)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (data.totalCents == BigInt.zero)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No spending to display', textAlign: TextAlign.center),
          ),
        const SizedBox(height: 16),
        for (var index = 0; index < data.categories.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: categoryChartColors[index],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.categories[index].category} · ${(data.categories[index].fraction * 100).toStringAsFixed(1)}%',
                      ),
                      Tooltip(
                        message: formatAnalyticsVnd(
                          data.categories[index].cents,
                        ),
                        child: Text(
                          compactAnalyticsVnd(data.categories[index].cents),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Draws precomputed category fractions; aggregation and labels live elsewhere.
class CategoryDonutPainter extends CustomPainter {
  CategoryDonutPainter({
    required List<double> fractions,
    required List<Color> colors,
    required this.progress,
    required this.trackColor,
  }) : fractions = List.unmodifiable(fractions),
       colors = List.unmodifiable(colors);
  final List<double> fractions;
  final List<Color> colors;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    if (diameter <= 0) return;
    final stroke = diameter * 0.14;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (diameter - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    var start = -math.pi / 2;
    var remaining = math.pi * 2 * progress.clamp(0.0, 1.0);
    for (var index = 0; index < fractions.length; index++) {
      final sweep = fractions[index] * math.pi * 2;
      final visible = math.min(sweep, remaining);
      if (visible > 0) {
        paint.color = colors[index];
        canvas.drawArc(rect, start, visible, false, paint);
      }
      remaining = math.max(0, remaining - sweep);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CategoryDonutPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      trackColor != oldDelegate.trackColor ||
      !listEquals(fractions, oldDelegate.fractions) ||
      !listEquals(colors, oldDelegate.colors);
}
