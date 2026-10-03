import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../repository/transaction_repository.dart';
import 'receipt_image_service.dart';

class ReceiptSaveService {
  ReceiptSaveService({
    TransactionRepository? repository,
    ReceiptImageService? images,
  }) : _repository = repository ?? TransactionRepository(),
       _images = images ?? ReceiptImageService();

  final TransactionRepository _repository;
  final ReceiptImageService _images;
  bool _saving = false;

  Future<TransactionModel> save({
    required String temporaryImagePath,
    required String merchant,
    required double amount,
    required DateTime date,
    required String category,
  }) async {
    if (_saving) throw StateError('A receipt save is already in progress.');
    if (merchant.trim().isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        category.trim().isEmpty) {
      throw ArgumentError('Valid receipt details are required.');
    }
    _saving = true;
    try {
      final imagePath = await _images.copyToDocuments(temporaryImagePath);
      final record = TransactionModel(
        merchant: merchant.trim(),
        amount: amount,
        date: date,
        category: category,
        receiptImagePath: imagePath,
        createdAt: DateTime.now(),
      );
      int id;
      try {
        id = await _repository.insertTransaction(record);
      } catch (_) {
        // Never delete the source. Remove only the uncommitted destination.
        try {
          await _images.discardDocumentCopy(imagePath);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Uncommitted receipt cleanup failed: $error');
          }
        }
        rethrow;
      }
      return TransactionModel(
        id: id,
        merchant: record.merchant,
        amount: record.amount,
        date: record.date,
        category: record.category,
        receiptImagePath: imagePath,
        createdAt: record.createdAt,
      );
    } finally {
      _saving = false;
    }
  }
}
