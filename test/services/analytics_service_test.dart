import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/analytics_service.dart';
import 'package:receiptwise/utils/analytics_format.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TransactionModel _record(double amount, String category, DateTime date) =>
    TransactionModel(
      merchant: 'Merchant',
      amount: amount,
      category: category,
      date: date,
      createdAt: date,
    );

void main() {
  final now = DateTime(2026, 10, 2, 12);
  test(
    'empty and zero spending yield finite zero fractions and seven calendar days',
    () {
      for (final records in [
        <TransactionModel>[],
        [_record(0, 'Food', now)],
      ]) {
        final data = AnalyticsService.aggregate(records, now: now);
        expect(data.totalCents, BigInt.zero);
        expect(data.categories.map((item) => item.category), [
          'Food',
          'Study',
          'Travel',
          'Gear',
          'Entertainment',
          'Other',
        ]);
        expect(data.days, hasLength(7));
        expect(data.days.first.date, DateTime(2026, 9, 26));
        expect(data.days.last.date, DateTime(2026, 10, 2));
        expect(data.categories.every((item) => item.fraction == 0), isTrue);
        expect(data.days.every((item) => item.heightFraction == 0), isTrue);
      }
    },
  );

  test(
    'groups all categories, fills empty days and excludes dates outside the week',
    () {
      final data = AnalyticsService.aggregate([
        _record(100, 'Food', DateTime(2026, 9, 26, 23, 59)),
        _record(50, 'Food', now),
        _record(50, 'Study', now),
        _record(200, 'Travel', DateTime(2026, 9, 25, 23, 59)),
        _record(300, 'Unknown', DateTime(2026, 10, 3)),
      ], now: now);
      expect(data.totalCents, BigInt.from(70000));
      expect(data.categories.first.cents, BigInt.from(15000));
      expect(data.categories.last.cents, BigInt.from(30000));
      expect(data.days.first.cents, BigInt.from(10000));
      expect(data.days.last.cents, BigInt.from(10000));
      expect(data.days[1].cents, BigInt.zero);
      expect(data.weeklyMaximumCents, BigInt.from(10000));
    },
  );

  test('single category is a full sweep and large totals never overflow', () {
    final single = AnalyticsService.aggregate([
      _record(150000, 'Food', now),
    ], now: now);
    expect(single.categories.first.fraction, 1);
    final large = AnalyticsService.aggregate([
      _record(1e308, 'Food', now),
      _record(1e308, 'Food', now),
      _record(1e308, 'Gear', now),
    ], now: now);
    expect(large.totalCents, BigInt.from(3) * BigInt.from(10).pow(310));
    expect(large.categories.first.fraction, closeTo(2 / 3, 1e-12));
    expect(large.days.last.heightFraction, 1);
    expect(large.categories.every((item) => item.fraction.isFinite), isTrue);
    expect(compactAnalyticsVnd(large.totalCents), '3 × 10^308 ₫');
  });

  test('rounds cents consistently and ignores invalid spending', () {
    expect(AnalyticsService.amountToCents(150000.50), BigInt.from(15000050));
    expect(AnalyticsService.amountToCents(0.105), BigInt.from(11));
    final data = AnalyticsService.aggregate([
      _record(double.infinity, 'Food', now),
      _record(double.nan, 'Food', now),
      _record(-100, 'Food', now),
    ], now: now);
    expect(data.totalCents, BigInt.zero);
    expect(formatAnalyticsVnd(BigInt.from(15000050)), '150.000,5 ₫');
  });

  test(
    'SQLite saved transactions supply analytics after repository updates/deletes',
    () async {
      sqfliteFfiInit();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final repository = TransactionRepository(database: database);
      final service = AnalyticsService(repository: repository);
      try {
        final id = await repository.insertTransaction(
          _record(150000, 'Food', now),
        );
        expect(
          (await service.load(now: now)).totalCents,
          BigInt.from(15000000),
        );
        await repository.updateTransaction(
          TransactionModel(
            id: id,
            merchant: 'Edited',
            amount: 200000,
            category: 'Study',
            date: now,
            createdAt: now,
          ),
        );
        final updated = await service.load(now: now);
        expect(updated.categories[1].fraction, 1);
        expect(updated.days.last.cents, BigInt.from(20000000));
        await repository.deleteTransaction(id);
        expect((await service.load(now: now)).transactionCount, 0);
      } finally {
        await database.close();
      }
    },
  );
}
