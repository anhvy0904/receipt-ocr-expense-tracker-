import 'package:flutter/material.dart';

import '../../models/receipt_review_draft.dart';
import '../../models/transaction_model.dart';
import '../../services/receipt_parser.dart';
import '../../services/transaction_management_service.dart';
import '../../utils/transaction_format.dart';

class TransactionEditScreen extends StatefulWidget {
  const TransactionEditScreen({
    required this.transaction,
    required this.managementService,
    super.key,
  });
  final TransactionModel transaction;
  final TransactionManagementService managementService;
  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _merchant = TextEditingController(
    text: widget.transaction.merchant,
  );
  late final _amount = TextEditingController(
    text: amountInputText(widget.transaction.amount),
  );
  late final _date = TextEditingController(
    text: formatTransactionDate(widget.transaction.date),
  );
  late String? _category =
      ReceiptReviewDraft.categories.contains(widget.transaction.category)
      ? widget.transaction.category
      : null;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    bool committed = false;
    final original = widget.transaction;
    final updated = TransactionModel(
      id: original.id,
      merchant: _merchant.text.trim(),
      amount: ReceiptParser.parseAmount(_amount.text)!,
      date: ReceiptParser.parseDate(_date.text)!,
      category: _category!,
      receiptImagePath: original.receiptImagePath,
      createdAt: original.createdAt,
    );
    try {
      await widget.managementService.updateTransaction(updated);
      committed = true;
      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update transaction. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted && !committed) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Edit transaction')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  textInputAction: TextInputAction.next,
                  controller: _merchant,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Merchant'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Merchant is required.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  textInputAction: TextInputAction.next,
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    suffixText: '₫',
                  ),
                  validator: (value) {
                    final amount = ReceiptParser.parseAmount(value ?? '');
                    return amount == null || amount <= 0
                        ? 'Enter an amount greater than zero.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _date,
                  enabled: !_saving,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'DD/MM/YYYY',
                  ),
                  validator: (value) =>
                      ReceiptParser.parseDate(value ?? '') == null
                      ? 'Enter a valid date (DD/MM/YYYY).'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  selectedItemBuilder: (_) => ReceiptReviewDraft.categories
                      .map(
                        (value) => Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                      .toList(),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ReceiptReviewDraft.categories
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _category = value),
                  validator: (value) =>
                      value == null ? 'Category is required.' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
