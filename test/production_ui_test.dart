import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/app/theme/app_theme.dart';
import 'package:receiptwise/models/receipt_capture_geometry.dart';
import 'package:receiptwise/models/transaction_model.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:receiptwise/services/transaction_management_service.dart';
import 'package:receiptwise/ui/screens/transaction_edit_screen.dart';
import 'package:receiptwise/ui/widgets/scanner_controls.dart';

void main() {
  testWidgets(
    'scanner buttons are accessible and guide clears enlarged instructions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      late Rect frame;
      late double controlsHeight;
      int captures = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Builder(
              builder: (context) {
                controlsHeight = ScannerControls.bottomHeight(context, 320);
                frame = receiptFrameForViewport(
                  const Size(320, 568),
                  EdgeInsets.zero,
                  controlsHeight: controlsHeight,
                );
                return ScannerControls(
                  ready: true,
                  busy: false,
                  torchOn: false,
                  changingFlash: false,
                  onClose: () {},
                  onFlash: () {},
                  onCapture: () => captures++,
                );
              },
            ),
          ),
        ),
      );
      expect(frame.isEmpty, isFalse);
      expect(frame.bottom, lessThanOrEqualTo(568 - controlsHeight));
      final capture = find.byTooltip('Capture receipt');
      final close = find.byTooltip('Close scanner');
      expect(tester.getSize(capture).height, greaterThanOrEqualTo(80));
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
      await tester.tap(capture);
      expect(captures, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edit form fits keyboard viewport and large category text in dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: TransactionEditScreen(
            transaction: TransactionModel(
              id: 1,
              merchant: 'Merchant',
              amount: 150000,
              date: DateTime(2026, 10, 1),
              category: 'Entertainment',
              createdAt: DateTime(2026, 10, 1),
            ),
            managementService: TransactionManagementService(
              repository: TransactionRepository(),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final theme = Theme.of(
        tester.element(find.byType(TransactionEditScreen)),
      );
      expect(theme.useMaterial3, isTrue);
      expect(theme.inputDecorationTheme.errorMaxLines, 3);
    },
  );
}
