import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/spending_analytics.dart';
import '../../utils/analytics_format.dart';
import '../../utils/transaction_format.dart';

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({required this.data, super.key});
  final SpendingAnalytics data;

  @override
  Widget build(BuildContext context) {
    final chartHeight = math.max(
      200.0,
      MediaQuery.textScalerOf(context).scale(12) * 14,
    );
    final heights = data.days.map((day) => day.heightFraction).toList();
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Latest 7 days', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${formatTransactionDate(data.days.first.date)} – ${formatTransactionDate(data.days.last.date)}',
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.weeklyMaximumCents > BigInt.zero)
              SizedBox(
                width: 92,
                height: chartHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cents in [
                      data.weeklyMaximumCents,
                      data.weeklyMaximumCents ~/ BigInt.two,
                      BigInt.zero,
                    ])
                      Tooltip(
                        message: formatAnalyticsVnd(cents),
                        child: Text(
                          compactAnalyticsVnd(cents),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: chartHeight,
                    child: TweenAnimationBuilder<double>(
                      key: ObjectKey(data),
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, progress, child) => CustomPaint(
                        size: Size(double.infinity, chartHeight),
                        painter: WeeklyBarPainter(
                          heights: heights,
                          progress: progress,
                          barColor: Theme.of(context).colorScheme.primary,
                          gridColor: Theme.of(
                            context,
                          ).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final day in data.days)
                        Expanded(
                          child: Tooltip(
                            message:
                                '${formatTransactionDate(day.date)}: ${formatAnalyticsVnd(day.cents)}',
                            child: Semantics(
                              label:
                                  '${formatTransactionDate(day.date)}, ${formatAnalyticsVnd(day.cents)}',
                              child: Text(
                                labels[day.date.weekday - 1],
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (data.weeklyMaximumCents == BigInt.zero)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('No spending in the latest 7 days'),
          ),
      ],
    );
  }
}

/// Receives normalized heights. No database queries or aggregation in paint.
class WeeklyBarPainter extends CustomPainter {
  WeeklyBarPainter({
    required List<double> heights,
    required this.progress,
    required this.barColor,
    required this.gridColor,
  }) : heights = List.unmodifiable(heights);
  final List<double> heights;
  final double progress;
  final Color barColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || heights.isEmpty) return;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = (size.height - 1) * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final paint = Paint()..color = barColor;
    final slot = size.width / heights.length;
    for (var index = 0; index < heights.length; index++) {
      final height =
          (size.height - 1) * heights[index] * progress.clamp(0.0, 1.0);
      if (height <= 0) continue;
      final rect = Rect.fromLTWH(
        slot * index + slot * 0.18,
        size.height - 1 - height,
        slot * 0.64,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyBarPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      barColor != oldDelegate.barColor ||
      gridColor != oldDelegate.gridColor ||
      !listEquals(heights, oldDelegate.heights);
}
