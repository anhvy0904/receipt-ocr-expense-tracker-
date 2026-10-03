import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/services/receipt_parser.dart';

void main() {
  test('currency fallback ignores unrelated phone and item numbers', () {
    expect(ReceiptParser().parse('0901234567 150.000đ').amount, 150000);
    expect(ReceiptParser().parse('Mã: 999999999 150 000 đ').amount, 150000);
  });
  test('Vietnamese total formats and merchant/date heuristics', () {
    for (final total in [
      '150,000 VND',
      '150.000 VND',
      '150.000đ',
      '150 000 đ',
      '150000',
    ]) {
      final receipt = ReceiptParser().parse(
        'HÓA ĐƠN\nCửa hàng Đà Lạt\n01/10/2026\nTỔNG CỘNG: $total',
      );
      expect(receipt.merchant, 'Cửa hàng Đà Lạt');
      expect(receipt.amount, 150000);
      expect(receipt.date, DateTime(2026, 10, 1));
    }
    expect(ReceiptParser().parse('THÀNH TIỀN: 150,000').amount, 150000);
    expect(ReceiptParser().parse('150 000 đ').amount, 150000);
    expect(ReceiptParser().parse('TỔNG CỘNG: -150.000 VND').amount, isNull);
  });

  test('total label wins over other amounts', () {
    final parsed = ReceiptParser().parse(
      'Cửa hàng\nTiền khách đưa: 500.000 VND\nTỔNG CỘNG: 150.000\nTiền thừa: 350.000 VND',
    );
    expect(parsed.amount, 150000);
  });

  test('null extraction leaves unavailable values unset', () {
    final parsed = ReceiptParser().parse('HÓA ĐƠN\nNgày: 31/02/2026');
    expect(parsed.merchant, isNull);
    expect(parsed.amount, isNull);
    expect(parsed.date, isNull);
  });

  test('strict dates reject normalization and inconsistent separators', () {
    for (final value in ['01/10/2026', '01-10-2026', '01.10.2026']) {
      expect(ReceiptParser.parseDate(value), DateTime(2026, 10, 1));
    }
    expect(ReceiptParser.parseDate('29/02/2024'), DateTime(2024, 2, 29));
    for (final value in [
      '31/02/2026',
      '29/02/2026',
      '01/13/2026',
      '00/10/2026',
      '01/10-2026',
      'abc',
    ]) {
      expect(ReceiptParser.parseDate(value), isNull);
    }
  });

  test('amount validation rejects malformed and nonfinite values', () {
    for (final value in ['', '-1', 'NaN', 'Infinity', '1,2,3', '12x']) {
      expect(ReceiptParser.parseAmount(value), isNull);
    }
    expect(ReceiptParser.parseAmount('150.000,50'), 150000.5);
    expect(ReceiptParser.parseAmount('150000.0'), 150000);
  });
}
