import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/state/transaction_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedRepository extends TransactionRepository {
  final requests = <Completer<List<TransactionModel>>>[];
  @override
  Future<List<TransactionModel>> getAllTransactions() {
    final request = Completer<List<TransactionModel>>();
    requests.add(request);
    return request.future;
  }
}

TransactionModel record(int id) => TransactionModel(
  id: id,
  merchant: 'Shop',
  amount: 150000,
  date: DateTime(2026, 10, 3),
  category: 'Food',
  createdAt: DateTime(2026, 10, 3),
);

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'Provider state refreshes after manual save, edit and delete using real SQLite',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final state = TransactionState(
        repository: TransactionRepository(database: database),
        now: () => DateTime(2026, 10, 3),
      );
      addTearDown(() async {
        state.dispose();
        await database.close();
      });
      await state.refresh();
      expect(state.records, isEmpty);
      final saved = await state.saveService.save(
        temporaryImagePath: null,
        merchant: 'Shop',
        amount: 150000,
        date: DateTime(2026, 10, 3),
        category: 'Food',
      );
      expect(saved.receiptImagePath, isNull);
      expect(state.records.single.id, saved.id);
      expect(state.homeSummary!.weeklyCents, BigInt.from(15000000));
      await state.managementService.updateTransaction(
        TransactionModel(
          id: saved.id,
          merchant: 'Edited',
          amount: 200000,
          date: saved.date,
          category: 'Study',
          createdAt: saved.createdAt,
        ),
      );
      expect(state.records.single.merchant, 'Edited');
      expect(state.analytics!.totalCents, BigInt.from(20000000));
      await state.managementService.deleteTransaction(saved.id!);
      expect(state.records, isEmpty);
      expect(state.homeSummary!.totalCents, BigInt.zero);
    },
  );

  test(
    'latest refresh wins and async completion after disposal is safe',
    () async {
      final repository = _DelayedRepository();
      final state = TransactionState(repository: repository);
      final first = state.refresh();
      final second = state.refresh();
      repository.requests[1].complete([record(2)]);
      await second;
      repository.requests[0].complete([record(1)]);
      await first;
      expect(state.records.single.id, 2);
      final pending = state.refresh();
      state.dispose();
      repository.requests[2].complete([]);
      await pending;
    },
  );

  test('load failure preserves data and exposes retry state', () async {
    final repository = _DelayedRepository();
    final state = TransactionState(repository: repository);
    addTearDown(state.dispose);
    final initial = state.refresh();
    repository.requests.last.complete([record(1)]);
    await initial;
    final failed = state.refresh();
    repository.requests.last.completeError(StateError('Database failed'));
    await failed;
    expect(state.failed, isTrue);
    expect(state.loading, isFalse);
    expect(state.records.single.id, 1);
    final retry = state.refresh();
    repository.requests.last.complete([]);
    await retry;
    expect(state.failed, isFalse);
    expect(state.records, isEmpty);
  });
}
