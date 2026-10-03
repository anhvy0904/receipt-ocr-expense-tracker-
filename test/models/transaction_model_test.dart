import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/models/transaction_model.dart';

void main() {
  test('round trips every stored field and normalizes date offsets to UTC', () {
    final original = TransactionModel(
      id: 42,
      merchant: 'Cửa hàng Việt',
      amount: 150000.5,
      date: DateTime.parse('2026-10-01T09:30:00.123456+07:00'),
      category: 'Food',
      receiptImagePath: '/documents/receipts/42.jpg',
      createdAt: DateTime.parse('2026-10-01T09:35:00+07:00'),
    );

    final map = original.toMap();
    expect(map['date'], '2026-10-01T02:30:00.123456Z');
    expect(map['created_at'], '2026-10-01T02:35:00.000000Z');
    final restored = TransactionModel.fromMap(map);
    expect(restored.id, original.id);
    expect(restored.merchant, original.merchant);
    expect(restored.amount, original.amount);
    expect(restored.date.isAtSameMomentAs(original.date), isTrue);
    expect(restored.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
    expect(restored.date.isUtc, isTrue);
    expect(restored.category, original.category);
    expect(restored.receiptImagePath, original.receiptImagePath);
  });

  test('handles unsaved IDs, absent receipt images, and integer amounts', () {
    final record = TransactionModel.fromMap({
      'merchant': 'Bookshop',
      'amount': 80000,
      'date': '2026-10-01T00:00:00Z',
      'category': 'Study',
      'receipt_image_path': null,
      'created_at': '2026-10-01T00:00:00Z',
    });
    expect(record.id, isNull);
    expect(record.receiptImagePath, isNull);
    expect(record.amount, 80000.0);
    expect(record.toMap().containsKey('id'), isFalse);
    expect(record.toMap()['receipt_image_path'], isNull);
  });

  test('canonical date strings sort correctly at microsecond boundaries', () {
    final start = DateTime.utc(2026, 10, 1);
    final dates = [
      start,
      start.add(const Duration(microseconds: 1)),
      start.add(const Duration(milliseconds: 1)),
      start.add(const Duration(milliseconds: 1, microseconds: 1)),
    ];
    final encoded = dates.map(TransactionModel.encodeDateTime).toList();
    final reversed = encoded.reversed.toList()..sort();
    expect(reversed, encoded);
    for (var index = 0; index < dates.length; index++) {
      expect(DateTime.parse(encoded[index]), dates[index]);
    }
  });
}
