import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/receipt_image_service.dart';
import 'package:receiptwise/services/transaction_management_service.dart';
import 'package:receiptwise/ui/screens/transactions_screen.dart';
import 'package:receiptwise/utils/transaction_format.dart';

class _Repository extends TransactionRepository {
  List<TransactionModel> records = [];
  int deletes = 0;
  bool failLoad = false;
  bool failUpdate = false;
  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    if (failLoad) throw StateError('Load failed');
    return records.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<TransactionModel?> getTransactionById(int id) async =>
      records.where((item) => item.id == id).firstOrNull;
  @override
  Future<int> updateTransaction(TransactionModel record) async {
    if (failUpdate) throw StateError('Update failed');
    final index = records.indexWhere((item) => item.id == record.id);
    records[index] = record;
    return 1;
  }

  @override
  Future<int> deleteTransaction(int id) async {
    deletes++;
    records.removeWhere((item) => item.id == id);
    return 1;
  }
}

class _Images extends ReceiptImageService {
  bool fail = true;
  int attempts = 0;
  @override
  Future<void> deleteStoredReceipt(String? imagePath) async {
    attempts++;
    if (fail) throw StateError('File locked');
  }
}

TransactionModel _record(
  int id,
  String merchant,
  int day, {
  String? imagePath,
}) => TransactionModel(
  id: id,
  merchant: merchant,
  amount: 150000,
  date: DateTime(2026, 10, day),
  category: 'Food',
  createdAt: DateTime(2026, 10, day),
  receiptImagePath: imagePath,
);

Future<void> _open(WidgetTester tester, _Repository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TransactionsScreen(repository: repository)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'large expense inputs remain editable and grouped instead of scientific notation',
    () {
      final input = amountInputText(1e30);
      expect(input, '1${'0' * 30}');
      expect(formatVnd(1e30), '1.000.000.000.000.000.000.000.000.000.000 ₫');
      expect(formatVnd(double.nan), 'Amount unavailable');
    },
  );

  testWidgets('duplicate history taps open only one detail route', (
    tester,
  ) async {
    await _open(tester, _Repository()..records = [_record(1, 'Merchant', 1)]);
    final open = tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text('Merchant'),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!;
    open();
    open();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Transaction detail'), findsNothing);
    expect(find.text('Transaction history'), findsOneWidget);
  });
  testWidgets('rows wrap on narrow screens with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _open(
      tester,
      _Repository()..records = [_record(1, 'A merchant with a long name', 1)],
    );
    expect(find.text('A merchant with a long name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('file cleanup can be retried without deleting the row again', (
    tester,
  ) async {
    final repository = _Repository()
      ..records = [_record(1, 'Merchant', 1, imagePath: '')];
    final images = _Images();
    final service = TransactionManagementService(
      repository: repository,
      images: images,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionsScreen(
            repository: repository,
            managementService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merchant'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text('The receipt image could not be removed.'),
      findsOneWidget,
    );
    expect(repository.deletes, 1);
    images.fail = false;
    await tester.tap(find.text('Retry image deletion'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 1);
    expect(images.attempts, 2);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  test('formats grouped VND and local dates', () {
    expect(formatVnd(150000), '150.000 ₫');
    expect(formatVnd(150000.5), '150.000,5 ₫');
    expect(formatTransactionDate(DateTime(2026, 10, 1)), '01/10/2026');
  });

  testWidgets('empty state and retry after load failure', (tester) async {
    final repository = _Repository()..failLoad = true;
    await _open(tester, repository);
    expect(find.text('Could not load transactions'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets(
    'newest first, detail fields, missing image and confirmed deletion',
    (tester) async {
      final repository = _Repository()
        ..records = [
          _record(1, 'Older merchant', 1),
          _record(2, 'Newer merchant', 2),
        ];
      await _open(tester, repository);
      expect(
        tester.getTopLeft(find.text('Newer merchant')).dy,
        lessThan(tester.getTopLeft(find.text('Older merchant')).dy),
      );
      expect(find.text('150.000 ₫'), findsNWidgets(2));
      expect(find.text('Food • 02/10/2026'), findsOneWidget);
      await tester.tap(find.text('Newer merchant'));
      await tester.pumpAndSettle();
      expect(find.text('Receipt image unavailable.'), findsOneWidget);
      expect(find.text('Category: Food'), findsOneWidget);
      expect(find.text('Date: 02/10/2026'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete transaction?'), findsOneWidget);
      expect(repository.deletes, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 1);
      expect(find.text('Newer merchant'), findsNothing);
      expect(find.text('Older merchant'), findsOneWidget);
    },
  );

  testWidgets(
    'edit validation and failure retain inputs; successful edit refreshes history',
    (tester) async {
      final repository = _Repository()..records = [_record(1, 'Merchant', 1)];
      await _open(tester, repository);
      await tester.tap(find.text('Merchant'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '');
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.text('Merchant is required.'), findsOneWidget);
      await tester.enterText(fields.at(0), 'Edited merchant');
      await tester.enterText(fields.at(1), '200000');
      await tester.enterText(fields.at(2), '03/10/2026');
      repository.failUpdate = true;
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update transaction. Please retry.'),
        findsOneWidget,
      );
      repository.failUpdate = false;
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edited merchant'), findsOneWidget);
      expect(find.text('200.000 ₫'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Edited merchant'), findsOneWidget);
      expect(find.text('Food • 03/10/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
