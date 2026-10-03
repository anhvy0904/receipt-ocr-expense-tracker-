import 'package:flutter/material.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/app/receiptwise_app.dart';

class _NoCameraPlatform extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => [];
}

void main() {
  late CameraPlatform original;
  setUp(() {
    original = CameraPlatform.instance;
    CameraPlatform.instance = _NoCameraPlatform();
  });
  tearDown(() => CameraPlatform.instance = original);
  testWidgets('launches Home and visits each navigation destination', (
    tester,
  ) async {
    await tester.pumpWidget(const ReceiptWiseApp());
    expect(find.text('Welcome to ReceiptWise'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).useMaterial3,
      isTrue,
    );

    for (final destination in {
      'Transactions': 'Transaction history',
      'Analytics': 'Expense analytics',
      'Home': 'Welcome to ReceiptWise',
    }.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destination.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Home action opens and closes the fullscreen scanner', (
    tester,
  ) async {
    await tester.pumpWidget(const ReceiptWiseApp());
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
    await tester.tap(find.byTooltip('Close scanner'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ReceiptWise'), findsOneWidget);
  });

  testWidgets('screens fit a small viewport with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ReceiptWiseApp());
    expect(tester.takeException(), isNull);
    for (final label in ['Scanner', 'Transactions', 'Analytics', 'Home']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (label == 'Scanner') {
        await tester.tap(find.byTooltip('Close scanner'));
        await tester.pumpAndSettle();
      }
    }
  });
}
