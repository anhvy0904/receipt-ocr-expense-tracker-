import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/transaction_model.dart';
import '../models/receipt_review_draft.dart';
import '../services/receipt_import_service.dart';
import '../state/transaction_state.dart';
import '../state/appearance_state.dart';
import '../ui/screens/receipt_import_screen.dart';
import '../ui/screens/review_receipt_screen.dart';

import '../ui/screens/analytics_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/scanner_screen.dart';
import '../ui/screens/transactions_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({this.importService, super.key});
  final ReceiptImportService? importService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _titles = ['Home', 'Scanner', 'Transactions', 'Analytics'];
  int _selectedIndex = 0;
  bool _scannerOpen = false;
  TransactionModel? _savedReceipt;
  late TransactionState _state;
  late ReceiptImportService _importer;

  @override
  void initState() {
    super.initState();
    _state = context.read<TransactionState>();
    _importer =
        widget.importService ?? ReceiptImportService(images: _state.images);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_recover()));
  }

  Future<void> _recover() async {
    try {
      final image = await _importer.recoverLostImage();
      if (mounted && image != null) await _openImport(recoveredImage: image);
    } catch (error) {
      if (kDebugMode) debugPrint('Image picker recovery failed: $error');
      if (mounted && error is! MissingPluginException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not recover the previous receipt image. Please choose it again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openImport({
    ImageSource source = ImageSource.gallery,
    XFile? recoveredImage,
  }) => _openInput(
    ReceiptImportScreen(
      service: _importer,
      saveService: _state.saveService,
      source: source,
      recoveredImage: recoveredImage,
    ),
  );

  Future<void> _manual() => _openInput(
    ReviewReceiptScreen(
      draft: const ReceiptReviewDraft(),
      canRetake: false,
      saveService: _state.saveService,
    ),
  );

  @override
  void dispose() {
    unawaited(
      _importer.dispose().catchError((Object error) {
        if (kDebugMode) debugPrint('Import OCR cleanup failed: $error');
      }),
    );
    super.dispose();
  }

  void _selectDestination(int index) {
    if (index == 1) {
      _openScanner();
      return;
    }
    setState(() => _selectedIndex = index);
    unawaited(_state.refresh());
  }

  Future<void> _openScanner() async {
    return _openInput(ScannerScreen(saveService: _state.saveService));
  }

  Future<void> _openInput(Widget screen) async {
    if (_scannerOpen) return;
    _scannerOpen = true;
    try {
      final saved = await Navigator.of(
        context,
      ).push<TransactionModel>(MaterialPageRoute(builder: (_) => screen));
      if (saved == null || !mounted) return;
      setState(() {
        _savedReceipt = saved;
        _selectedIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully.')),
      );
    } finally {
      _scannerOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransactionState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Appearance',
            initialValue: context.read<AppearanceState>().mode,
            onSelected: context.read<AppearanceState>().select,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ThemeMode.system,
                child: Text('System appearance'),
              ),
              PopupMenuItem(
                value: ThemeMode.light,
                child: Text('Light appearance'),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark appearance'),
              ),
            ],
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              state: state,
              onImportReceipt: _openImport,
              onPickerCamera: () => _openImport(source: ImageSource.camera),
              onManualEntry: _manual,
              onScanReceipt: () => _selectDestination(1),
              onViewTransactions: () => _selectDestination(2),
              active: _selectedIndex == 0,
              revision: state.revision,
              selectedReceiptPath: _savedReceipt?.receiptImagePath,
            ),
            const SizedBox.shrink(),
            TransactionsScreen(
              state: state,
              repository: state.repository,
              managementService: state.managementService,
              active: _selectedIndex == 2,
              revision: state.revision,
              onTransactionChanged: (id, record) {
                setState(() {
                  if (_savedReceipt?.id == id) _savedReceipt = record;
                });
              },
            ),
            AnalyticsScreen(
              state: state,
              active: _selectedIndex == 3,
              revision: state.revision,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
