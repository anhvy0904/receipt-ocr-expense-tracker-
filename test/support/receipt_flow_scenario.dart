import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:receiptwise/app/receiptwise_app.dart';
import 'package:receiptwise/models/ocr_result.dart';
import 'package:receiptwise/models/receipt_review_draft.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/receipt_image_service.dart';
import 'package:receiptwise/services/receipt_import_service.dart';
import 'package:receiptwise/state/transaction_state.dart';

class FixtureReceiptImport extends ReceiptImportService {
  FixtureReceiptImport(this.receiptPath, this.storage) : super(images: storage);
  final String receiptPath;
  final ReceiptImageService storage;
  @override
  Future<XFile?> recoverLostImage() async => null;
  @override
  Future<ReceiptReviewDraft?> acquire(ImageSource source) async =>
      ReceiptReviewDraft(
        imagePath: receiptPath,
        ocrResult: OcrResult(
          fullText: 'DEMO SHOP\nNgay: 03/10/2026\nTong cong\n150.000 VND',
          blocks: [],
        ),
      );
}

Future<void> _waitUntil(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Flow did not finish');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Future<void> _nav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pump();
  final state = tester
      .element(find.byType(NavigationBar))
      .read<TransactionState>();
  await _waitUntil(tester, () => !state.loading);
}

Future<void> _pressSave(WidgetTester tester, {String label = 'Save'}) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> exerciseReceiptFlow(
  WidgetTester tester, {
  required TransactionRepository repository,
  required Directory root,
  Directory? screenshots,
}) async {
  final storage = ReceiptImageService(
    temporaryDirectoryProvider: () async => root,
    documentsDirectoryProvider: () async => Directory('${root.path}/documents'),
  );
  final photoPath = (await tester.runAsync(
    storage.createTemporaryReceiptPath,
  ))!;
  await tester.runAsync(() async {
    final receipt = image.Image(width: 400, height: 600);
    image.fill(receipt, color: image.ColorRgb8(255, 255, 255));
    image.drawString(
      receipt,
      'DEMO SHOP',
      font: image.arial24,
      x: 30,
      y: 40,
      color: image.ColorRgb8(0, 0, 0),
    );
    image.drawString(
      receipt,
      '03/10/2026',
      font: image.arial24,
      x: 30,
      y: 100,
      color: image.ColorRgb8(0, 0, 0),
    );
    image.drawString(
      receipt,
      'TOTAL: 150.000 VND',
      font: image.arial24,
      x: 30,
      y: 180,
      color: image.ColorRgb8(0, 0, 0),
    );
    await File(photoPath).writeAsBytes(image.encodeJpg(receipt));
  });
  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: ReceiptWiseApp(
        repository: repository,
        images: storage,
        importService: FixtureReceiptImport(photoPath, storage),
      ),
    ),
  );
  final state = tester
      .element(find.byType(NavigationBar))
      .read<TransactionState>();
  await _waitUntil(tester, () => !state.loading);
  expect(state.failed, isFalse);

  Future<void> capture(String name) async {
    if (screenshots == null) return;
    for (final element in find.byType(Image).evaluate()) {
      bool ready = false;
      final pending = precacheImage(
        (element.widget as Image).image,
        element,
      ).whenComplete(() => ready = true);
      await _waitUntil(tester, () => ready);
      await pending;
    }
    await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final png = await render.toImage(pixelRatio: 1.5);
      final bytes = await png.toByteData(format: ImageByteFormat.png);
      png.dispose();
      await screenshots.create(recursive: true);
      await File(
        '${screenshots.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  await capture('home-light');
  await tester.tap(find.byTooltip('Appearance'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dark appearance'));
  await tester.pumpAndSettle();
  expect(
    Theme.of(tester.element(find.byType(NavigationBar))).brightness,
    Brightness.dark,
  );
  await capture('home-dark');
  await tester.tap(find.text('Choose receipt image'));
  await tester.pumpAndSettle();
  expect(find.text('Review Receipt'), findsOneWidget);
  expect((await tester.runAsync(repository.getAllTransactions))!, isEmpty);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Merchant'),
    'Verified Shop',
  );
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Food').last);
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.ensureVisible(find.widgetWithText(TextFormField, 'Merchant'));
  await tester.pumpAndSettle();
  await capture('review');
  await _pressSave(tester);
  await _waitUntil(tester, () => state.records.length == 1 && !state.loading);
  final saved = state.records.single;
  expect(saved.merchant, 'Verified Shop');
  expect(saved.amount, 150000);
  expect(saved.category, 'Food');
  expect(
    await tester.runAsync(() => File(saved.receiptImagePath!).exists()),
    isTrue,
  );

  await _nav(tester, 'Transactions');
  await _waitUntil(tester, () => !state.loading);
  await capture('history');
  await tester.tap(find.text('Verified Shop'));
  await tester.pump();
  // The detail query crosses the actual SQLite boundary.
  await _waitUntil(tester, () => find.text('Edit').evaluate().isNotEmpty);
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Amount'),
    '200000',
  );
  await _pressSave(tester, label: 'Save changes');
  await _waitUntil(
    tester,
    () => state.records.single.amount == 200000 && !state.loading,
  );
  await tester.pageBack();
  await tester.pump();
  await _waitUntil(tester, () => !state.loading);
  await _nav(tester, 'Analytics');
  await _waitUntil(tester, () => !state.loading);
  expect(state.analytics!.totalCents, BigInt.from(20000000));
  ScaffoldMessenger.of(
    tester.element(find.byType(NavigationBar)),
  ).clearSnackBars();
  await capture('analytics');
  await tester.ensureVisible(find.text('Latest 7 days'));
  await tester.pumpAndSettle();
  await capture('weekly-bars');
  await _nav(tester, 'Transactions');
  await _waitUntil(tester, () => !state.loading);
  await tester.tap(find.text('Verified Shop'));
  await tester.pump();
  await _waitUntil(tester, () => find.text('Delete').evaluate().isNotEmpty);
  await tester.ensureVisible(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ),
  );
  await _waitUntil(tester, () => state.records.isEmpty && !state.loading);
  try {
    await _waitUntil(
      tester,
      () =>
          find.text('Transaction detail').evaluate().isEmpty ||
          find.text('Retry image deletion').evaluate().isNotEmpty,
    );
    if (find.text('Retry image deletion').evaluate().isNotEmpty) {
      await tester.tap(find.text('Retry image deletion'));
      await tester.pump();
    }
  } catch (_) {
    debugPrint(
      'Visible fixture flow state: ${find.byType(Text).evaluate().map((element) => (element.widget as Text).data).join(' | ')}',
    );
    rethrow;
  }
  await _waitUntil(
    tester,
    () => find.text('Transaction detail').evaluate().isEmpty,
  );
  expect((await tester.runAsync(repository.getAllTransactions))!, isEmpty);
  expect(
    await tester.runAsync(() => File(saved.receiptImagePath!).exists()),
    isFalse,
  );
  await tester.pumpWidget(const SizedBox.shrink());
}
