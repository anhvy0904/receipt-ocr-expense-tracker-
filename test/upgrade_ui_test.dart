import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receiptwise/app/receiptwise_app.dart';
import 'package:receiptwise/models/receipt_review_draft.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/receipt_import_service.dart';

class _Repository extends TransactionRepository {
  TransactionModel? saved;
  @override
  Future<List<TransactionModel>> getAllTransactions() async =>
      saved == null ? [] : [saved!];
  @override
  Future<int> insertTransaction(TransactionModel record) async {
    saved = TransactionModel.fromMap({...record.toMap(), 'id': 1});
    return 1;
  }
}

class _Importer extends ReceiptImportService {
  final pending = Completer<ReceiptReviewDraft?>();
  int calls = 0;
  @override
  Future<XFile?> recoverLostImage() async => null;
  @override
  Future<ReceiptReviewDraft?> acquire(ImageSource source) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('manual entry validates and saves without a receipt image', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      ReceiptWiseApp(repository: repository, importService: _Importer()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enter expense manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter expense manually'));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Merchant is required.'), findsOneWidget);
    expect(repository.saved, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Merchant'),
      'Manual Book',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '50000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Date'),
      '03/10/2026',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.saved!.merchant, 'Manual Book');
    expect(repository.saved!.receiptImagePath, isNull);
    expect(find.text('Transaction saved successfully.'), findsOneWidget);
  });

  testWidgets(
    'duplicate gallery actions open one picker and cancellation preserves data',
    (tester) async {
      final repository = _Repository();
      final importer = _Importer();
      await tester.pumpWidget(
        ReceiptWiseApp(repository: repository, importService: importer),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Choose receipt image'),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(importer.calls, 1);
      importer.pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ReceiptWise'), findsOneWidget);
      expect(repository.saved, isNull);
    },
  );
}
