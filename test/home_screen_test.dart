import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/app/theme/app_theme.dart';
import 'package:receiptwise/models/home_summary.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/home_summary_service.dart';
import 'package:receiptwise/ui/screens/home_screen.dart';

class _Repository extends TransactionRepository {
  _Repository(this.records);
  final List<TransactionModel> records;
  @override
  Future<List<TransactionModel>> getAllTransactions() async => records;
}

class _Service extends HomeSummaryService {
  HomeSummary? data;
  bool fail = false;
  Completer<HomeSummary>? pending;
  int calls = 0;
  @override
  Future<HomeSummary> load({DateTime? now}) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('Load failed');
    return data ?? _empty();
  }
}

HomeSummary _empty() => HomeSummary(
  totalCents: BigInt.zero,
  weeklyCents: BigInt.zero,
  transactionCount: 0,
  recentTransactions: [],
);

TransactionModel _record(int id, DateTime date, double amount) =>
    TransactionModel(
      id: id,
      merchant: 'Receipt $id',
      amount: amount,
      date: date,
      category: 'Food',
      createdAt: date,
    );

Widget _app(_Service service, {int revision = 0}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: HomeScreen(
      service: service,
      revision: revision,
      onScanReceipt: () {},
    ),
  ),
);

void main() {
  test(
    'summary uses latest seven calendar days and limits recent receipts',
    () async {
      final now = DateTime(2026, 10, 3);
      final records = [
        _record(4, now, 150000),
        _record(3, DateTime(2026, 9, 27), 25000),
        _record(2, DateTime(2026, 9, 26), 30000),
        _record(1, DateTime(2026, 9, 1), 10000),
      ];
      final summary = await HomeSummaryService(
        repository: _Repository(records),
      ).load(now: now);
      expect(summary.totalCents, BigInt.from(21500000));
      expect(summary.weeklyCents, BigInt.from(17500000));
      expect(summary.transactionCount, 4);
      expect(summary.recentTransactions.map((record) => record.id), [4, 3, 2]);
    },
  );

  testWidgets(
    'loading, failure retry and empty state leave scanner available',
    (tester) async {
      final service = _Service()..fail = true;
      await tester.pumpWidget(_app(service));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Open scanner'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Could not load spending summary.'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('0 saved transactions'), findsOneWidget);
    },
  );

  testWidgets('summary reloads after transaction revision changes', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    service.data = HomeSummary(
      totalCents: BigInt.from(15000000),
      weeklyCents: BigInt.from(15000000),
      transactionCount: 1,
      recentTransactions: [_record(1, DateTime(2026, 10, 3), 150000)],
    );
    await tester.pumpWidget(_app(service, revision: 1));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('1 saved transactions'), findsOneWidget);
    expect(find.text('Receipt 1'), findsOneWidget);
  });

  testWidgets('pending loading completes safely after disposal', (
    tester,
  ) async {
    final service = _Service()..pending = Completer<HomeSummary>();
    await tester.pumpWidget(_app(service));
    await tester.pumpWidget(const SizedBox.shrink());
    service.pending!.complete(_empty());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('large values and text fit a narrow dashboard', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = _Service()
      ..data = HomeSummary(
        totalCents: BigInt.from(10).pow(302),
        weeklyCents: BigInt.from(10).pow(302),
        transactionCount: 1,
        recentTransactions: [_record(1, DateTime(2026, 10, 3), 1e300)],
      );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
