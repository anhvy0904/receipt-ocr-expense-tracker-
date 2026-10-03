import '../models/receipt_review_draft.dart';
import '../models/transaction_model.dart';
import '../repository/transaction_repository.dart';
import 'receipt_image_service.dart';

class TransactionDeletionResult {
  const TransactionDeletionResult({this.pendingImagePath});
  final String? pendingImagePath;
}

class TransactionManagementService {
  TransactionManagementService({
    required this._repository,
    ReceiptImageService? images,
  }) : _images = images ?? ReceiptImageService();
  final TransactionRepository _repository;
  final ReceiptImageService _images;

  Future<void> updateTransaction(TransactionModel record) async {
    if (record.id == null ||
        record.merchant.trim().isEmpty ||
        !record.amount.isFinite ||
        record.amount <= 0 ||
        !ReceiptReviewDraft.categories.contains(record.category)) {
      throw ArgumentError('Valid transaction details are required');
    }
    if (await _repository.updateTransaction(record) == 0) {
      throw StateError('Transaction no longer exists');
    }
  }

  Future<TransactionDeletionResult> deleteTransaction(int id) async {
    final record = await _repository.getTransactionById(id);
    if (record == null) return const TransactionDeletionResult();
    // Delete the row first: database failure must never destroy its receipt.
    await _repository.deleteTransaction(id);
    try {
      await _images.deleteStoredReceipt(record.receiptImagePath);
      return const TransactionDeletionResult();
    } catch (_) {
      return TransactionDeletionResult(
        pendingImagePath: record.receiptImagePath,
      );
    }
  }

  /// A cleanup retry never repeats the database deletion.
  Future<void> retryImageDeletion(String imagePath) =>
      _images.deleteStoredReceipt(imagePath);
}
