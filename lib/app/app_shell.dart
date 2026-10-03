import 'package:flutter/material.dart';

import '../models/transaction_model.dart';

import '../ui/screens/analytics_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/scanner_screen.dart';
import '../ui/screens/transactions_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _titles = ['Home', 'Scanner', 'Transactions', 'Analytics'];
  int _selectedIndex = 0;
  bool _scannerOpen = false;
  TransactionModel? _savedReceipt;
  int _transactionRevision = 0;

  void _selectDestination(int index) {
    if (index == 1) {
      _openScanner();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _openScanner() async {
    if (_scannerOpen) return;
    _scannerOpen = true;
    try {
      final saved = await Navigator.of(context).push<TransactionModel>(
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      );
      if (saved == null || !mounted) return;
      setState(() {
        _savedReceipt = saved;
        _transactionRevision++;
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
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeScreen(
              onScanReceipt: () => _selectDestination(1),
              onViewTransactions: () => _selectDestination(2),
              active: _selectedIndex == 0,
              revision: _transactionRevision,
              selectedReceiptPath: _savedReceipt?.receiptImagePath,
            ),
            const SizedBox.shrink(),
            TransactionsScreen(
              active: _selectedIndex == 2,
              revision: _transactionRevision,
              onTransactionChanged: (id, record) {
                setState(() {
                  _transactionRevision++;
                  if (_savedReceipt?.id == id) _savedReceipt = record;
                });
              },
            ),
            AnalyticsScreen(
              active: _selectedIndex == 3,
              revision: _transactionRevision,
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
