import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TransactionModel record({
  int? id,
  String merchant = 'Cửa hàng Việt',
  double amount = 150000,
  DateTime? date,
  String category = 'Food',
  String? receiptImagePath,
  DateTime? createdAt,
}) {
  return TransactionModel(
    id: id,
    merchant: merchant,
    amount: amount,
    date: date ?? DateTime.utc(2026, 10, 1),
    category: category,
    receiptImagePath: receiptImagePath,
    createdAt: createdAt ?? DateTime.utc(2026, 10, 1, 1),
  );
}

void main() {
  late AppDatabase database;
  late TransactionRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = TransactionRepository(database: database);
  });

  tearDown(() async => database.close());

  test(
    'concurrent closes share one operation and new opens wait for completion',
    () async {
      final original = await database.database;
      final close = database.close();
      expect(identical(close, database.close()), isTrue);
      final reopen = database.database;
      await close;
      final fresh = await reopen;
      expect(identical(fresh, original), isFalse);
      expect(fresh.isOpen, isTrue);
      expect(await repository.getAllTransactions(), isEmpty);
    },
  );

  test(
    'creates the requested schema with one shared lazy connection',
    () async {
      final connections = await Future.wait([
        database.database,
        database.database,
      ]);
      expect(identical(connections[0], connections[1]), isTrue);
      final db = connections.first;
      expect(await db.getVersion(), AppDatabase.schemaVersion);
      final columns = await db.rawQuery('PRAGMA table_info(transactions)');
      expect(columns.map((column) => column['name']), [
        'id',
        'merchant',
        'amount',
        'date',
        'category',
        'receipt_image_path',
        'created_at',
      ]);
      expect(columns.map((column) => column['type']), [
        'INTEGER',
        'TEXT',
        'REAL',
        'TEXT',
        'TEXT',
        'TEXT',
        'TEXT',
      ]);
      expect(columns.map((column) => column['notnull']), [0, 1, 1, 1, 1, 0, 1]);
      expect(columns.first['pk'], 1);
      final schema = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        [AppDatabase.transactionsTable],
      );
      expect(schema.single['sql'], contains('AUTOINCREMENT'));
    },
  );

  test(
    'inserts, retrieves, updates all fields, clears images, and deletes',
    () async {
      final original = record(receiptImagePath: '/documents/receipts/one.jpg');
      final id = await repository.insertTransaction(original);
      expect(id, greaterThan(0));
      expect(original.id, isNull);
      final saved = await repository.getTransactionById(id);
      expect(saved!.id, id);
      expect(saved.merchant, original.merchant);
      expect(saved.amount, original.amount);
      expect(saved.receiptImagePath, original.receiptImagePath);

      final updated = record(
        id: id,
        merchant: "Joe's books; DROP TABLE transactions; --",
        amount: 80000.5,
        date: DateTime.utc(2026, 10, 2),
        category: 'Study',
        createdAt: DateTime.utc(2026, 10, 1, 2),
      );
      expect(await repository.updateTransaction(updated), 1);
      expect(
        (await repository.getTransactionById(id))!.toMap(),
        updated.toMap(),
      );
      expect(await repository.deleteTransaction(id), 1);
      expect(await repository.getTransactionById(id), isNull);
      expect(await repository.getAllTransactions(), isEmpty);
      expect(await repository.deleteTransaction(id), 0);
      expect(await repository.updateTransaction(updated), 0);
      final nextId = await repository.insertTransaction(record());
      expect(nextId, greaterThan(id));
    },
  );

  test('empty and missing queries return an empty list and null', () async {
    expect(await repository.getAllTransactions(), isEmpty);
    expect(await repository.getTransactionById(999), isNull);
    expect(
      await repository.getTransactionsBetweenDates(
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 2),
      ),
      isEmpty,
    );
  });

  test('orders by transaction date then ID descending', () async {
    final olderId = await repository.insertTransaction(record());
    final newerId = await repository.insertTransaction(
      record(date: DateTime.utc(2026, 10, 2)),
    );
    final tiedId = await repository.insertTransaction(record());
    expect((await repository.getAllTransactions()).map((item) => item.id), [
      newerId,
      tiedId,
      olderId,
    ]);
  });

  test(
    'date ranges include boundaries and preserve microsecond accuracy',
    () async {
      final start = DateTime.utc(2026, 10, 1);
      final end = start.add(const Duration(milliseconds: 1));
      await repository.insertTransaction(
        record(date: start.subtract(const Duration(microseconds: 1))),
      );
      final startId = await repository.insertTransaction(record(date: start));
      final middleId = await repository.insertTransaction(
        record(date: start.add(const Duration(microseconds: 1))),
      );
      final endId = await repository.insertTransaction(record(date: end));
      await repository.insertTransaction(
        record(date: end.add(const Duration(microseconds: 1))),
      );
      expect(
        (await repository.getTransactionsBetweenDates(
          start,
          end,
        )).map((item) => item.id),
        [endId, middleId, startId],
      );
      expect(
        (await repository.getTransactionsBetweenDates(
          start,
          start,
        )).map((item) => item.id),
        [startId],
      );
      expect(
        (await repository.getTransactionsBetweenDates(
          DateTime.parse('2026-10-01T07:00:00+07:00'),
          DateTime.parse('2026-10-01T07:00:00.001+07:00'),
        )).map((item) => item.id),
        [endId, middleId, startId],
      );
    },
  );

  test('invalid IDs and reversed date bounds are rejected', () async {
    await expectLater(
      repository.insertTransaction(record(id: 1)),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateTransaction(record()),
      throwsArgumentError,
    );
    await expectLater(
      repository.getTransactionsBetweenDates(
        DateTime.utc(2026, 10, 2),
        DateTime.utc(2026, 10, 1),
      ),
      throwsArgumentError,
    );
    expect(await repository.getAllTransactions(), isEmpty);
  });

  test('the file database survives closing and reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'receiptwise_test_',
    );
    final fileDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path.join(directory.path, 'receiptwise.db'),
    );
    try {
      final fileRepository = TransactionRepository(database: fileDatabase);
      final id = await fileRepository.insertTransaction(record());
      await fileDatabase.close();
      final restored = await fileRepository.getTransactionById(id);
      expect(restored!.merchant, 'Cửa hàng Việt');
      expect(restored.amount, 150000);
    } finally {
      await fileDatabase.close();
      await directory.delete(recursive: true);
    }
  });
}
