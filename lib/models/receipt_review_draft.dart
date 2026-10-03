import 'ocr_result.dart';

/// Review input. Constructing this draft never inserts a transaction.
class ReceiptReviewDraft {
  static const categories = [
    'Food',
    'Study',
    'Travel',
    'Gear',
    'Entertainment',
    'Other',
  ];
  const ReceiptReviewDraft({
    this.imagePath,
    this.imageDescription = 'Cropped receipt',
    this.ocrResult,
    this.ocrFailed = false,
    this.merchant = '',
    this.amount = '',
    this.date = '',
    this.category = 'Other',
  });

  final String? imagePath;
  final String imageDescription;
  final OcrResult? ocrResult;
  final bool ocrFailed;
  final String merchant;
  final String amount;
  final String date;
  final String category;
}
