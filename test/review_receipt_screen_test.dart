import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/models/ocr_result.dart';
import 'package:receiptwise/app/theme/app_theme.dart';
import 'package:receiptwise/models/receipt_review_draft.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/services/receipt_save_service.dart';
import 'package:receiptwise/ui/screens/review_receipt_screen.dart';

class _SaveService extends ReceiptSaveService {
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;
  TransactionModel? saved;
  @override
  Future<TransactionModel> save({
    required String? temporaryImagePath,
    required String merchant,
    required double amount,
    required DateTime date,
    required String category,
  }) async {
    calls++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Insert failed');
    return saved = TransactionModel(
      id: 1,
      merchant: merchant,
      amount: amount,
      date: date,
      category: category,
      receiptImagePath: '/documents/receipt.jpg',
      createdAt: DateTime.now(),
    );
  }
}

Future<void> _openReview(
  WidgetTester tester,
  ReceiptReviewDraft draft,
  _SaveService service, {
  void Function(TransactionModel?)? onReturn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<TransactionModel>(
                MaterialPageRoute(
                  builder: (_) =>
                      ReviewReceiptScreen(draft: draft, saveService: service),
                ),
              );
              onReturn?.call(result);
            },
            child: const Text('Review'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
}

Future<void> pressSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pump();
}

void main() {
  testWidgets('Save stays disabled after commit while the route closes', (
    tester,
  ) async {
    final service = _SaveService();
    await _openReview(
      tester,
      const ReceiptReviewDraft(
        imagePath: '/temporary.jpg',
        merchant: 'Merchant',
        amount: '150000',
        date: '01/10/2026',
      ),
      service,
    );
    await pressSave(tester);
    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(buttons.single.onPressed, isNull);
    expect(service.calls, 1);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
  });
  testWidgets(
    'review fits a small keyboard viewport and enlarged category text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = _SaveService();
      await _openReview(
        tester,
        const ReceiptReviewDraft(
          imagePath: '/missing.jpg',
          merchant: 'Merchant',
          amount: '150000',
          date: '01/10/2026',
          category: 'Entertainment',
        ),
        service,
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await pressSave(tester);
      await tester.pumpAndSettle();
      expect(service.saved!.category, 'Entertainment');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending save completes safely after review is unmounted', (
    tester,
  ) async {
    final service = _SaveService()..pending = Completer<void>();
    await _openReview(
      tester,
      const ReceiptReviewDraft(
        imagePath: '/temporary.jpg',
        merchant: 'Merchant',
        amount: '150000',
        date: '01/10/2026',
      ),
      service,
    );
    await pressSave(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    service.pending!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('prefills parser values; edited values are explicitly saved', (
    tester,
  ) async {
    final service = _SaveService();
    TransactionModel? returned;
    await _openReview(
      tester,
      ReceiptReviewDraft(
        imagePath: '/missing.jpg',
        ocrResult: OcrResult(
          fullText: 'Cửa hàng Việt\nTỔNG CỘNG: 150.000\n01/10/2026',
          blocks: [],
        ),
      ),
      service,
      onReturn: (value) => returned = value,
    );
    final fields = find.byType(TextFormField);
    final widgets = tester.widgetList<TextFormField>(fields).toList();
    expect(widgets[0].controller!.text, 'Cửa hàng Việt');
    expect(widgets[1].controller!.text, '150000.0');
    expect(widgets[2].controller!.text, '01/10/2026');
    expect(service.calls, 0);
    await tester.enterText(fields.at(0), 'Edited merchant');
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), '200000');
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), '02/10/2026');
    await pressSave(tester);
    await tester.pumpAndSettle();
    expect(returned!.merchant, 'Edited merchant');
    expect(returned!.amount, 200000);
    expect(returned!.date, DateTime(2026, 10, 2));
    expect(returned!.category, 'Other');
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing extraction stays empty; invalid fields block save', (
    tester,
  ) async {
    final service = _SaveService();
    await _openReview(
      tester,
      const ReceiptReviewDraft(
        imagePath: '/missing.jpg',
        ocrFailed: true,
        category: '',
      ),
      service,
    );
    final fields = find.byType(TextFormField);
    for (final field in tester.widgetList<TextFormField>(fields)) {
      expect(field.controller!.text, isEmpty);
    }
    await pressSave(tester);
    expect(service.calls, 0);
    expect(find.text('Merchant is required.'), findsOneWidget);
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(find.text('Enter a valid date (DD/MM/YYYY).'), findsOneWidget);
    expect(find.text('Category is required.'), findsOneWidget);
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), '0');
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), '31/02/2026');
    await pressSave(tester);
    expect(service.calls, 0);
  });

  testWidgets(
    'save failure retains edits and allows retry; pending save disables controls',
    (tester) async {
      final service = _SaveService()..fail = true;
      await _openReview(
        tester,
        const ReceiptReviewDraft(
          imagePath: '/temporary.jpg',
          ocrFailed: true,
          merchant: 'Manual merchant',
          amount: '150000',
          date: '01/10/2026',
        ),
        service,
      );
      await pressSave(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save receipt. Your edits are retained. Retry or retake if the photo is unavailable.',
        ),
        findsOneWidget,
      );
      expect(service.calls, 1);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Manual merchant',
      );
      service.fail = false;
      service.pending = Completer<void>();
      await pressSave(tester);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Retake'))
            .onPressed,
        isNull,
      );
      expect(service.calls, 2);
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(service.calls, 2);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
