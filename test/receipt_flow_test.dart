import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/repository/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/receipt_flow_scenario.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  testWidgets(
    'receipt review, Provider, SQLite, edit, analytics and delete flow',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      final fontPath = Platform.environment['RECEIPTWISE_SCREENSHOT_FONT'];
      if (fontPath != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('Roboto')
            ..addFont(
              File(
                fontPath,
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        });
      }
      final iconFontPath =
          Platform.environment['RECEIPTWISE_MATERIAL_ICON_FONT'];
      if (iconFontPath != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('MaterialIcons')
            ..addFont(
              File(
                iconFontPath,
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        });
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('receiptwise_flow_'),
      ))!;
      final database = AppDatabase(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: '${root.path}/transactions.db',
      );
      try {
        await exerciseReceiptFlow(
          tester,
          repository: TransactionRepository(database: database),
          root: root,
          screenshots: Platform.environment['RECEIPTWISE_CAPTURE_UI'] == '1'
              ? Directory('docs/screenshots')
              : null,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        bool closed = false;
        final closing = database.close().whenComplete(() => closed = true);
        while (!closed) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await closing;
        await tester.runAsync(() => root.delete(recursive: true));
      }
    },
  );
}
