/// An expense record. A null [id] represents a transaction not yet inserted.
class TransactionModel {
  const TransactionModel({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.receiptImagePath,
    required this.createdAt,
  });

  final int? id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String? receiptImagePath;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'merchant': merchant,
      'amount': amount,
      'date': encodeDateTime(date),
      'category': category,
      'receipt_image_path': receiptImagePath,
      'created_at': encodeDateTime(createdAt),
    };
  }

  factory TransactionModel.fromMap(Map<String, Object?> map) {
    return TransactionModel(
      id: map['id'] as int?,
      merchant: map['merchant'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      receiptImagePath: map['receipt_image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// UTC ISO-8601 with six fractional digits so SQLite text ordering preserves
  /// chronological order even when records have different microsecond values.
  static String encodeDateTime(DateTime value) {
    final utc = value.toUtc();
    final iso = utc.toIso8601String();
    if (utc.microsecond == 0) {
      return '${iso.substring(0, iso.length - 1)}000Z';
    }
    return iso;
  }
}
