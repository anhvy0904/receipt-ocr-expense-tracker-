import 'package:flutter/material.dart';

import '../../models/home_summary.dart';
import '../../services/home_summary_service.dart';
import '../../state/transaction_state.dart';
import '../../utils/analytics_format.dart';
import '../../utils/transaction_format.dart';
import '../widgets/receipt_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.onScanReceipt,
    this.onViewTransactions,
    this.onImportReceipt,
    this.onPickerCamera,
    this.onManualEntry,
    this.state,
    this.selectedReceiptPath,
    this.service,
    this.active = true,
    this.revision = 0,
    super.key,
  });

  final VoidCallback onScanReceipt;
  final VoidCallback? onViewTransactions;
  final VoidCallback? onImportReceipt;
  final VoidCallback? onPickerCamera;
  final VoidCallback? onManualEntry;
  final TransactionState? state;
  final String? selectedReceiptPath;
  final HomeSummaryService? service;
  final bool active;
  final int revision;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _service = widget.service ?? HomeSummaryService();
  HomeSummary? _summary;
  bool _loading = false;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active && widget.state == null) _load();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == null &&
        widget.active &&
        (!oldWidget.active || widget.revision != oldWidget.revision)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.state != null) return widget.state!.refresh();
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await _service.load();
      if (mounted && request == _request) setState(() => _summary = data);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Widget _amount(String title, BigInt cents) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Tooltip(
              message: formatAnalyticsVnd(cents),
              child: Text(
                compactAnalyticsVnd(cents),
                semanticsLabel: formatAnalyticsVnd(cents),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.state?.homeSummary ?? _summary;
    final loading = widget.state?.loading ?? _loading;
    final failed = widget.state?.failed ?? _failed;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome to ReceiptWise',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan a receipt, review its details and save an expense on this device.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onScanReceipt,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Open scanner'),
            ),
            if (widget.onPickerCamera != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onPickerCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take receipt photo'),
              ),
            ],
            if (widget.onImportReceipt != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onImportReceipt,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose receipt image'),
              ),
            ],
            if (widget.onManualEntry != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onManualEntry,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Enter expense manually'),
              ),
            ],
            if (widget.selectedReceiptPath != null) ...[
              const SizedBox(height: 16),
              const Text('Transaction saved on this device.'),
            ],
            const SizedBox(height: 24),
            if (loading)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading spending summary',
                ),
              )
            else if (failed) ...[
              const Text('Could not load spending summary.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ] else if (summary != null) ...[
              _amount('Total spending', summary.totalCents),
              const SizedBox(height: 12),
              _amount('Latest 7 days', summary.weeklyCents),
              const SizedBox(height: 16),
              Text(
                '${summary.transactionCount} saved transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'Recent transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (summary.recentTransactions.isEmpty)
                const Text('No transactions yet')
              else
                for (final record in summary.recentTransactions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReceiptImage(
                          imagePath: record.receiptImagePath,
                          thumbnail: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.merchant,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${record.category} • ${formatTransactionDate(record.date)}',
                              ),
                              Text(
                                formatVnd(record.amount),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              if (widget.onViewTransactions != null)
                OutlinedButton.icon(
                  onPressed: widget.onViewTransactions,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View transactions'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
