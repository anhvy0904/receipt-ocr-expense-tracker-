import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/models/spending_analytics.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/services/analytics_service.dart';
import 'package:receiptwise/ui/screens/analytics_screen.dart';
import 'package:receiptwise/ui/widgets/category_donut_chart.dart';
import 'package:receiptwise/ui/widgets/weekly_bar_chart.dart';

class _Service extends AnalyticsService {
  _Service(this.data);
  SpendingAnalytics data;
  bool fail = false;
  @override
  Future<SpendingAnalytics> load({DateTime? now}) async {
    if (fail) throw StateError('Database unavailable');
    return data;
  }
}

Future<ByteData> _render(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(100, 100));
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Color _pixel(ByteData data, int x, int y) {
  final offset = (y * 100 + x) * 4;
  return Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 2, 12);
  SpendingAnalytics data(double amount) => AnalyticsService.aggregate([
    TransactionModel(
      merchant: 'Merchant',
      amount: amount,
      date: now,
      category: 'Food',
      createdAt: now,
    ),
  ], now: now);

  test(
    'donut animates from track to a full single-category ring with an empty center',
    () async {
      final start = await _render(
        CategoryDonutPainter(
          fractions: [1],
          colors: [Colors.red],
          progress: 0,
          trackColor: Colors.grey,
        ),
      );
      final end = await _render(
        CategoryDonutPainter(
          fractions: [1],
          colors: [Colors.red],
          progress: 1,
          trackColor: Colors.grey,
        ),
      );
      expect(_pixel(start, 50, 7).toARGB32(), Colors.grey.toARGB32());
      expect(_pixel(end, 50, 7).toARGB32(), Colors.red.toARGB32());
      expect(_pixel(end, 50, 50).a, 0);
    },
  );

  test(
    'weekly bars draw normalized heights and animate upward from zero',
    () async {
      final start = await _render(
        WeeklyBarPainter(
          heights: [0.5, 1],
          progress: 0,
          barColor: Colors.red,
          gridColor: Colors.grey,
        ),
      );
      final end = await _render(
        WeeklyBarPainter(
          heights: [0.5, 1],
          progress: 1,
          barColor: Colors.red,
          gridColor: Colors.grey,
        ),
      );
      expect(_pixel(start, 25, 75).a, 0);
      expect(_pixel(end, 25, 75).toARGB32(), Colors.red.toARGB32());
      expect(_pixel(end, 25, 25).a, 0);
      expect(_pixel(end, 75, 25).toARGB32(), Colors.red.toARGB32());
    },
  );

  test(
    'shouldRepaint compares drawing data, animation progress and theme colors',
    () {
      CategoryDonutPainter donut(
        double progress, {
        List<double> fractions = const [1],
        Color track = Colors.grey,
      }) => CategoryDonutPainter(
        fractions: fractions,
        colors: [Colors.red],
        progress: progress,
        trackColor: track,
      );
      expect(donut(1).shouldRepaint(donut(1)), isFalse);
      expect(donut(0.5).shouldRepaint(donut(1)), isTrue);
      expect(donut(1, fractions: [0.5]).shouldRepaint(donut(1)), isTrue);
      expect(donut(1, track: Colors.black).shouldRepaint(donut(1)), isTrue);
      WeeklyBarPainter bars(
        double progress, {
        List<double> heights = const [1],
        Color color = Colors.red,
      }) => WeeklyBarPainter(
        heights: heights,
        progress: progress,
        barColor: color,
        gridColor: Colors.grey,
      );
      expect(bars(1).shouldRepaint(bars(1)), isFalse);
      expect(bars(0.5).shouldRepaint(bars(1)), isTrue);
      expect(bars(1, heights: [0]).shouldRepaint(bars(1)), isTrue);
      expect(bars(1, color: Colors.black).shouldRepaint(bars(1)), isTrue);
    },
  );

  testWidgets('loading error retries into the no-transactions state', (
    tester,
  ) async {
    final service = _Service(AnalyticsService.aggregate([], now: now))
      ..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnalyticsScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load analytics'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('charts animate, show legend percentages and day labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnalyticsScreen(service: _Service(data(150000)))),
      ),
    );
    await tester.pump();
    final donut = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((widget) => widget.painter is CategoryDonutPainter)
        .single;
    expect((donut.painter! as CategoryDonutPainter).progress, 0);
    await tester.pumpAndSettle();
    expect(find.text('Food · 100.0%'), findsOneWidget);
    expect(find.text('Study · 0.0%'), findsOneWidget);
    await tester.ensureVisible(find.byType(WeeklyBarChart));
    expect(find.text('Latest 7 days'), findsOneWidget);
    expect(find.text('CN'), findsOneWidget);
    final finalPainter =
        tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .where((widget) => widget.painter is CategoryDonutPainter)
                .single
                .painter!
            as CategoryDonutPainter;
    expect(finalPainter.progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'zero and enormous spending fit narrow screens with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final amount in [0.0, 1e308]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(amount),
            home: Scaffold(
              body: AnalyticsScreen(service: _Service(data(amount))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(WeeklyBarChart));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
