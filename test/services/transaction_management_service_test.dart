import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/receipt_image_service.dart';
import 'package:receiptwise/services/transaction_management_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FailingRepository extends TransactionRepository {
  _FailingRepository({required super.database});
  @override
  Future<int> deleteTransaction(int id) async =>
      throw StateError('Database unavailable');
}

class _FailingImages extends ReceiptImageService {
  _FailingImages(Directory directory)
    : super(documentsDirectoryProvider: () async => directory);
  bool fail = true;
  @override
  Future<void> deleteStoredReceipt(String? imagePath) async {
    if (fail) throw const FileSystemException('Access denied');
    await super.deleteStoredReceipt(imagePath);
  }
}

void main() {
  late Directory documents;
  late AppDatabase database;
  late TransactionRepository repository;
  late ReceiptImageService images;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    documents = await Directory.systemTemp.createTemp('receipt_history_test_');
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
    await documents.delete(recursive: true);
  });
  Future<int> insert(String? imagePath) => repository.insertTransaction(
    TransactionModel(
      merchant: 'Merchant',
      amount: 150000,
      date: DateTime(2026, 10, 1),
      category: 'Food',
      receiptImagePath: imagePath,
      createdAt: DateTime.utc(2026, 10, 2),
    ),
  );

  test('deletes database row and existing receipt image', () async {
    final image = await File(
      path.join(documents.path, 'receipt.jpg'),
    ).writeAsBytes([1]);
    final id = await insert(image.path);
    final result = await TransactionManagementService(
      repository: repository,
      images: images,
    ).deleteTransaction(id);
    expect(await repository.getTransactionById(id), isNull);
    expect(await image.exists(), isFalse);
    expect(result.pendingImagePath, isNull);
  });

  test('missing and null image paths are valid deletions', () async {
    final service = TransactionManagementService(
      repository: repository,
      images: images,
    );
    for (final image in [null, path.join(documents.path, 'missing.jpg')]) {
      final id = await insert(image);
      expect((await service.deleteTransaction(id)).pendingImagePath, isNull);
      expect(await repository.getTransactionById(id), isNull);
    }
  });

  test('database failure leaves image and row intact', () async {
    final image = await File(
      path.join(documents.path, 'receipt.jpg'),
    ).writeAsBytes([1]);
    final id = await insert(image.path);
    final service = TransactionManagementService(
      repository: _FailingRepository(database: database),
      images: images,
    );
    await expectLater(service.deleteTransaction(id), throwsStateError);
    expect(await image.exists(), isTrue);
    expect(await repository.getTransactionById(id), isNotNull);
  });

  test(
    'image cleanup failure returns retry path after successful row deletion',
    () async {
      final image = await File(
        path.join(documents.path, 'receipt.jpg'),
      ).writeAsBytes([1]);
      final id = await insert(image.path);
      final failing = _FailingImages(documents);
      final service = TransactionManagementService(
        repository: repository,
        images: failing,
      );
      final result = await service.deleteTransaction(id);
      expect(result.pendingImagePath, image.path);
      expect(await repository.getTransactionById(id), isNull);
      expect(await image.exists(), isTrue);
      failing.fail = false;
      await service.retryImageDeletion(result.pendingImagePath!);
      expect(await image.exists(), isFalse);
    },
  );

  test('edit retains image and original creation timestamp', () async {
    final image = await File(
      path.join(documents.path, 'receipt.jpg'),
    ).writeAsBytes([1]);
    final id = await insert(image.path);
    final original = (await repository.getTransactionById(id))!;
    await TransactionManagementService(
      repository: repository,
      images: images,
    ).updateTransaction(
      TransactionModel(
        id: id,
        merchant: 'Edited',
        amount: 200000,
        date: DateTime(2026, 10, 3),
        category: 'Study',
        receiptImagePath: original.receiptImagePath,
        createdAt: original.createdAt,
      ),
    );
    final updated = (await repository.getTransactionById(id))!;
    expect(updated.merchant, 'Edited');
    expect(updated.amount, 200000);
    expect(updated.category, 'Study');
    expect(updated.receiptImagePath, image.path);
    expect(updated.createdAt, original.createdAt);
    expect(await image.exists(), isTrue);
  });
}
