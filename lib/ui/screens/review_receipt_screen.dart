import 'package:flutter/material.dart';

import '../../models/expense_source.dart';
import '../../models/receipt_review_draft.dart';
import '../../models/transaction_model.dart';
import '../../services/receipt_parser.dart';
import '../../services/receipt_save_service.dart';
import '../../utils/transaction_format.dart';
import '../widgets/receipt_image.dart';

class ReviewReceiptScreen extends StatefulWidget {
  const ReviewReceiptScreen({
    required this.draft,
    this.canRetake = true,
    this.saveService,
    super.key,
  });

  final ReceiptReviewDraft draft;
  final bool canRetake;
  final ReceiptSaveService? saveService;

  @override
  State<ReviewReceiptScreen> createState() => _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends State<ReviewReceiptScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late final TextEditingController _date;
  late final ReceiptSaveService _saveService;
  late final ParsedReceipt _parsed;
  String? _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parsed = ReceiptParser().parse(
      widget.draft.ocrResult?.fullText ?? '',
    );
    _merchant = TextEditingController(
      text: widget.draft.merchant.isNotEmpty
          ? widget.draft.merchant
          : _parsed.merchant ?? '',
    );
    _amount = TextEditingController(
      text: widget.draft.amount.isNotEmpty
          ? widget.draft.amount
          : _parsed.amount == null
          ? ''
          : amountInputText(_parsed.amount!),
    );
    _date = TextEditingController(
      text: widget.draft.date.isNotEmpty
          ? widget.draft.date
          : _parsed.date == null
          ? ''
          : ReceiptParser.formatDate(_parsed.date!),
    );
    final suggested = _parsed.suggestedCategory;
    _category = widget.draft.category.isEmpty
        ? null
        : (ReceiptReviewDraft.categories.contains(widget.draft.category) &&
                widget.draft.category != 'Other')
        ? widget.draft.category
        : (suggested != null && ReceiptReviewDraft.categories.contains(suggested))
        ? suggested
        : (ReceiptReviewDraft.categories.contains(widget.draft.category)
            ? widget.draft.category
            : null);
    _saveService = widget.saveService ?? ReceiptSaveService();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    bool committed = false;
    try {
      final TransactionModel saved = await _saveService.save(
        temporaryImagePath: widget.draft.imagePath,
        merchant: _merchant.text,
        amount: ReceiptParser.parseAmount(_amount.text)!,
        date: ReceiptParser.parseDate(_date.text)!,
        category: _category!,
      );
      committed = true;
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.draft.imagePath == null
                ? 'Could not save expense. Your edits are retained. Please retry.'
                : 'Could not save receipt. Your edits are retained. Retry or retake if the photo is unavailable.',
          ),
        ),
      );
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
  Widget build(BuildContext context) {
    final text = widget.draft.ocrResult?.fullText ?? '';
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.draft.imagePath == null ? 'Add expense' : 'Review Receipt',
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.draft.imagePath != null) ...[
                    Semantics(
                      label: widget.draft.imageDescription,
                      child: ReceiptImage(imagePath: widget.draft.imagePath),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    widget.draft.imagePath == null
                        ? 'Enter the expense details. Nothing is saved until you confirm.'
                        : widget.draft.ocrFailed
                        ? 'Text recognition failed. Enter the receipt details manually.'
                        : text.trim().isEmpty
                        ? 'No text was found. Enter the receipt details manually.'
                        : 'Check the extracted details and edit anything that needs correcting.',
                  ),
                  if (_parsed.source != ExpenseSource.receipt || _parsed.provider != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(_parsed.source.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parsed.provider != null
                                      ? '${_parsed.source.labelVi}: ${_parsed.provider}'
                                      : _parsed.source.labelVi,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_parsed.transactionReference != null)
                                  Text(
                                    'Mã GD: ${_parsed.transactionReference}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          if (_parsed.status != PaymentStatus.unknown)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _parsed.status == PaymentStatus.successful
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _parsed.status.labelVi,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _parsed.status == PaymentStatus.successful
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_parsed.status == PaymentStatus.failed || _parsed.status == PaymentStatus.pending) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _parsed.status == PaymentStatus.failed
                            ? Colors.red.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _parsed.status == PaymentStatus.failed
                              ? Colors.red.shade300
                              : Colors.amber.shade400,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _parsed.status == PaymentStatus.failed
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline,
                            color: _parsed.status == PaymentStatus.failed
                                ? Colors.red.shade700
                                : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _parsed.status == PaymentStatus.failed
                                  ? 'Cảnh báo: Ảnh chụp có dấu hiệu giao dịch không thành công hoặc bị hủy. Vui lòng kiểm tra lại.'
                                  : 'Lưu ý: Giao dịch đang chờ xử lý (pending). Vui lòng kiểm tra lại.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _parsed.status == PaymentStatus.failed
                                    ? Colors.red.shade900
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                    controller: _merchant,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Merchant is required.'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Merchant',
                      helperText: _parsed.source != ExpenseSource.receipt
                          ? 'Người nhận / Đơn vị thụ hưởng'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                    controller: _amount,
                    validator: (value) {
                      final amount = ReceiptParser.parseAmount(value ?? '');
                      return amount == null || amount <= 0
                          ? 'Enter an amount greater than zero.'
                          : null;
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      suffixText: '₫',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    enabled: !_saving,
                    controller: _date,
                    validator: (value) =>
                        ReceiptParser.parseDate(value ?? '') == null
                        ? 'Enter a valid date (DD/MM/YYYY).'
                        : null,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      hintText: 'DD/MM/YYYY',
                    ),
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
                    validator: (value) => value == null || value.isEmpty
                        ? 'Category is required.'
                        : null,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ReceiptReviewDraft.categories
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _category = value),
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ExpansionTile(
                      title: const Text('Recognized text'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(text),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Save confirms these details and stores the expense on this device.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(widget.canRetake ? 'Retake' : 'Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
