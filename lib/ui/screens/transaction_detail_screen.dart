import 'package:flutter/material.dart';

import '../../models/transaction_model.dart';
import '../../repository/transaction_repository.dart';
import '../../services/transaction_management_service.dart';
import '../../utils/transaction_format.dart';
import '../widgets/receipt_image.dart';
import '../widgets/placeholder_content.dart';
import 'transaction_edit_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    required this.transactionId,
    required this.repository,
    required this.managementService,
    this.onTransactionChanged,
    super.key,
  });
  final int transactionId;
  final TransactionRepository repository;
  final TransactionManagementService managementService;
  final void Function(int id, TransactionModel? record)? onTransactionChanged;
  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel? _record;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _deleted = false;
  String? _pendingImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final record = await widget.repository.getTransactionById(
        widget.transactionId,
      );
      if (mounted) setState(() => _record = record);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit() async {
    if (_busy || _record == null) return;
    setState(() => _busy = true);
    final updated = await Navigator.of(context).push<TransactionModel>(
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(
          transaction: _record!,
          managementService: widget.managementService,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (updated != null) _record = updated;
    });
    if (updated != null) {
      widget.onTransactionChanged?.call(widget.transactionId, updated);
      _message('Transaction updated.');
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This will remove the transaction and its receipt image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    try {
      final result = await widget.managementService.deleteTransaction(
        widget.transactionId,
      );
      if (!mounted) return;
      _deleted = true;
      widget.onTransactionChanged?.call(widget.transactionId, null);
      if (result.pendingImagePath != null) {
        setState(() => _pendingImage = result.pendingImagePath);
      } else {
        _message('Transaction deleted.');
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      _message('Could not delete transaction. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryCleanup() async {
    if (_busy || _pendingImage == null) return;
    setState(() => _busy = true);
    try {
      await widget.managementService.retryImageDeletion(_pendingImage!);
      if (mounted) {
        _message('Transaction and receipt image deleted.');
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      _message('Could not remove receipt image. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaction detail')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? PlaceholderContent(
                  icon: Icons.error_outline,
                  title: 'Could not load transaction',
                  description: 'Please try again.',
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                )
              : _deleted
              ? PlaceholderContent(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaction deleted',
                  description: 'The receipt image could not be removed.',
                  action: Column(
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _retryCleanup,
                        child: const Text('Retry image deletion'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(true),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                )
              : record == null
              ? const PlaceholderContent(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaction not found',
                  description: 'It may have already been deleted.',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReceiptImage(imagePath: record.receiptImagePath),
                      const SizedBox(height: 20),
                      Text(
                        record.merchant,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        formatVnd(record.amount),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Date: ${formatTransactionDate(record.date)}'),
                      Text('Category: ${record.category}'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
