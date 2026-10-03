import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repository/transaction_repository.dart';
import '../services/receipt_image_service.dart';
import '../services/receipt_import_service.dart';
import '../state/appearance_state.dart';
import '../state/transaction_state.dart';

import 'app_shell.dart';
import 'theme/app_theme.dart';

class ReceiptWiseApp extends StatelessWidget {
  const ReceiptWiseApp({
    this.repository,
    this.images,
    this.importService,
    super.key,
  });
  final TransactionRepository? repository;
  final ReceiptImageService? images;
  final ReceiptImportService? importService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              TransactionState(repository: repository, images: images)
                ..refresh(),
        ),
        ChangeNotifierProvider(create: (_) => AppearanceState()),
      ],
      child: Consumer<AppearanceState>(
        builder: (context, appearance, _) => MaterialApp(
          title: 'ReceiptWise',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appearance.mode,
          home: AppShell(importService: importService),
        ),
      ),
    );
  }
}
