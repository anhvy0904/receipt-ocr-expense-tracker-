import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/placeholder_content.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onScanReceipt,
    this.selectedReceiptPath,
    super.key,
  });

  final VoidCallback onScanReceipt;
  final String? selectedReceiptPath;

  @override
  Widget build(BuildContext context) {
    return PlaceholderContent(
      icon: Icons.receipt_long_outlined,
      title: 'Welcome to ReceiptWise',
      description:
          'Scan a receipt, review its details and save an expense on this device. '
          'Visit Transactions and Analytics to explore your spending.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectedReceiptPath != null) ...[
            Image.file(
              File(selectedReceiptPath!),
              height: 160,
              fit: BoxFit.contain,
              semanticLabel: 'Saved receipt',
              errorBuilder: (context, error, stack) =>
                  const Text('Selected photo unavailable.'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Transaction saved on this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: onScanReceipt,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Open scanner'),
          ),
        ],
      ),
    );
  }
}
