import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/receipt_image_service.dart';
import 'package:receiptwise/services/receipt_save_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedRepository extends TransactionRepository {
  final finish = Completer<int>();
  final started = Completer<void>();
  @override
  Future<int> insertTransaction(TransactionModel record) {
    started.complete();
    return finish.future;
  }
}

class _FailingRepository extends TransactionRepository {
  @override
  Future<int> insertTransaction(TransactionModel record) async =>
      throw StateError('Database unavailable');
}

void main() {
  late Directory root;
  late Directory documents;
  late File source;
  late AppDatabase database;
  late TransactionRepository repository;
  late ReceiptImageService images;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt_save_test_');
    documents = Directory(path.join(root.path, 'documents'));
    source = await File(
      path.join(root.path, 'temporary.jpg'),
    ).writeAsBytes([1, 2, 3, 4]);
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = TransactionRepository(database: database);
    images = ReceiptImageService(
      documentsDirectoryProvider: () async => documents,
    );
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });
  Future<TransactionModel> save(ReceiptSaveService service) => service.save(
    temporaryImagePath: source.path,
    merchant: ' Merchant ',
    amount: 150000,
    date: DateTime(2026, 10, 1),
    category: 'Food',
  );

  test(
    'copy precedes insert; SQLite stores only document path; filenames are unique',
    () async {
      final service = ReceiptSaveService(
        repository: repository,
        images: images,
      );
      final first = await save(service);
      final second = await save(service);
      expect(first.receiptImagePath, isNot(second.receiptImagePath));
      expect(
        path.basename(first.receiptImagePath!),
        isNot(path.basename(second.receiptImagePath!)),
      );
      expect(path.isWithin(documents.path, first.receiptImagePath!), isTrue);
      expect(await File(first.receiptImagePath!).readAsBytes(), [1, 2, 3, 4]);
      final stored = await repository.getTransactionById(first.id!);
      expect(stored!.receiptImagePath, first.receiptImagePath);
      expect(stored.merchant, 'Merchant');
      expect(await source.exists(), isTrue);
      expect(stored.toMap()['receipt_image_path'], isA<String>());
    },
  );

  test(
    'failed insert removes only destination, source survives and retry succeeds',
    () async {
      await expectLater(
        save(
          ReceiptSaveService(repository: _FailingRepository(), images: images),
        ),
        throwsStateError,
      );
      expect(await source.readAsBytes(), [1, 2, 3, 4]);
      expect(await documents.list().toList(), isEmpty);
      expect(await repository.getAllTransactions(), isEmpty);
      expect(
        (await save(
          ReceiptSaveService(repository: repository, images: images),
        )).id,
        isNotNull,
      );
    },
  );

  test('copy failure inserts nothing', () async {
    await source.delete();
    await expectLater(
      save(ReceiptSaveService(repository: repository, images: images)),
      throwsA(isA<FileSystemException>()),
    );
    expect(await repository.getAllTransactions(), isEmpty);
    expect(await documents.list().toList(), isEmpty);
  });

  test('duplicate concurrent save is rejected', () async {
    final delayed = _DelayedRepository();
    final service = ReceiptSaveService(repository: delayed, images: images);
    final pending = save(service);
    await delayed.started.future;
    await expectLater(save(service), throwsStateError);
    delayed.finish.complete(1);
    await pending;
    expect(await documents.list().toList(), hasLength(1));
  });
}
