import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../repository/transaction_repository.dart';
import '../../services/transaction_management_service.dart';
import '../../utils/transaction_format.dart';
import '../widgets/receipt_image.dart';
import '../widgets/placeholder_content.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    this.repository,
    this.managementService,
    this.active = true,
    this.revision = 0,
    this.onTransactionChanged,
    super.key,
  });
  final TransactionRepository? repository;
  final TransactionManagementService? managementService;
  final bool active;
  final int revision;
  final void Function(int id, TransactionModel? record)? onTransactionChanged;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final _repository = widget.repository ?? TransactionRepository();
  late final _management =
      widget.managementService ??
      TransactionManagementService(repository: _repository);
  List<TransactionModel> _records = [];
  bool _loading = false;
  bool _failed = false;
  int _request = 0;
  bool _detailOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active || widget.revision != oldWidget.revision)) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final records = await _repository.getAllTransactions();
      if (!mounted || request != _request) return;
      setState(() => _records = records);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(TransactionModel record) async {
    if (_detailOpen) return;
    _detailOpen = true;
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(
            transactionId: record.id!,
            repository: _repository,
            managementService: _management,
            onTransactionChanged: widget.onTransactionChanged,
          ),
        ),
      );
      if (mounted) await _load();
    } finally {
      _detailOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Transaction history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh transactions',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? PlaceholderContent(
                  icon: Icons.error_outline,
                  title: 'Could not load transactions',
                  description: 'Please try again.',
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              : _records.isEmpty
              ? const PlaceholderContent(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  description:
                      'Scan a receipt and confirm Save to add an expense.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Semantics(
                        button: true,
                        child: InkWell(
                          onTap: () => _open(record),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ReceiptImage(
                                  imagePath: record.receiptImagePath,
                                  thumbnail: true,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.merchant,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${record.category} • ${formatTransactionDate(record.date)}',
                                      ),
                                      Text(
                                        formatVnd(record.amount),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
