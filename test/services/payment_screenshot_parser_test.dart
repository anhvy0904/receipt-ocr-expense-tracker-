import 'package:flutter_test/flutter_test.dart';
import 'package:receiptwise/models/expense_source.dart';
import 'package:receiptwise/services/payment_screenshot_parser.dart';
import 'package:receiptwise/services/receipt_parser.dart';

void main() {
  group('PaymentScreenshotParser', () {
    const parser = PaymentScreenshotParser();

    test('parses Vietcombank transfer screenshot successfully', () {
      const rawText = '''
Vietcombank
CHUYỂN TIỀN THÀNH CÔNG
Số tiền: 500.000 VND
Người thụ hưởng: NGUYỄN VĂN A
Ngân hàng thụ hưởng: MB Bank
Ngày thực hiện: 18/05/2026 14:32:00
Mã giao dịch: VCB88492019
Nội dung: Tiền cơm trưa
''';

      expect(parser.isPaymentScreenshot(rawText), isTrue);
      final result = parser.parse(rawText);

      expect(result.source, ExpenseSource.bankTransfer);
      expect(result.provider, 'Vietcombank');
      expect(result.status, PaymentStatus.successful);
      expect(result.amount, 500000);
      expect(result.recipient, contains('NGUYỄN VĂN A'));
      expect(result.date, DateTime(2026, 5, 18));
      expect(result.transactionReference, 'VCB88492019');
      expect(result.note, contains('Tiền cơm trưa'));
      expect(result.suggestedCategory, 'Food');
    });

    test('parses MoMo payment confirmation screenshot', () {
      const rawText = '''
MoMo
Giao dịch thành công
Số tiền: 120.000 đ
Thanh toán cho: Highlands Coffee
Thời gian: 15/05/2026 09:15
Mã giao dịch: MM987654321
Dịch vụ: Cà phê và đồ uống
''';

      expect(parser.isPaymentScreenshot(rawText), isTrue);
      final result = parser.parse(rawText);

      expect(result.source, ExpenseSource.eWallet);
      expect(result.provider, 'MoMo');
      expect(result.status, PaymentStatus.successful);
      expect(result.amount, 120000);
      expect(result.recipient, contains('Highlands Coffee'));
      expect(result.date, DateTime(2026, 5, 15));
      expect(result.transactionReference, 'MM987654321');
      expect(result.suggestedCategory, 'Food');
    });

    test('detects failed bank transaction status correctly', () {
      const rawText = '''
MB Bank
Giao dịch không thành công
Số tiền: 300.000 VND
Tài khoản thụ hưởng: TRẦN THỊ B
Ngày: 16/05/2026
Mã giao dịch: MB999222
''';

      final result = parser.parse(rawText);
      expect(result.source, ExpenseSource.bankTransfer);
      expect(result.provider, 'MB Bank');
      expect(result.status, PaymentStatus.failed);
      expect(result.amount, 300000);
      expect(result.recipient, contains('TRẦN THỊ B'));
    });

    test('detects pending payment status', () {
      const rawText = '''
ZaloPay
Đang chờ xử lý
Số tiền: 85.000 đ
Dịch vụ: GrabBike
Ngày: 14/05/2026
''';

      final result = parser.parse(rawText);
      expect(result.source, ExpenseSource.eWallet);
      expect(result.provider, 'ZaloPay');
      expect(result.status, PaymentStatus.pending);
      expect(result.amount, 85000);
      expect(result.suggestedCategory, 'Travel');
    });
  });

  group('ReceiptParser Unified Integration', () {
    test('routes bank screenshot automatically through ReceiptParser', () {
      const rawText = '''
Techcombank
Chuyển khoản thành công
Số tiền: 1.500.000 VND
Người nhận: NHÀ SÁCH FAHASA
Ngày: 10/05/2026
Mã GD: TCB777888
Nội dung: Mua sách giáo trình
''';

      final parsed = ReceiptParser().parse(rawText);
      expect(parsed.source, ExpenseSource.bankTransfer);
      expect(parsed.provider, 'Techcombank');
      expect(parsed.amount, 1500000);
      expect(parsed.merchant, contains('NHÀ SÁCH FAHASA'));
      expect(parsed.date, DateTime(2026, 5, 10));
      expect(parsed.status, PaymentStatus.successful);
      expect(parsed.transactionReference, 'TCB777888');
      expect(parsed.suggestedCategory, 'Study');
    });

    test('retains standard behavior for paper receipts', () {
      const rawText = '''
HÓA ĐƠN BÁN HÀNG
Cửa hàng Đà Lạt
01/10/2026
TỔNG CỘNG: 150.000 VND
''';

      final parsed = ReceiptParser().parse(rawText);
      expect(parsed.source, ExpenseSource.receipt);
      expect(parsed.merchant, 'Cửa hàng Đà Lạt');
      expect(parsed.amount, 150000);
      expect(parsed.date, DateTime(2026, 10, 1));
    });
  });
}
