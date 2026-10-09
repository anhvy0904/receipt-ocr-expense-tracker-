import '../models/expense_source.dart';
import 'receipt_parser.dart';

class ParsedPaymentScreenshot {
  const ParsedPaymentScreenshot({
    required this.source,
    this.provider,
    this.recipient,
    this.amount,
    this.date,
    this.status = PaymentStatus.unknown,
    this.transactionReference,
    this.note,
    this.suggestedCategory,
  });

  final ExpenseSource source;
  final String? provider;
  final String? recipient;
  final double? amount;
  final DateTime? date;
  final PaymentStatus status;
  final String? transactionReference;
  final String? note;
  final String? suggestedCategory;
}

/// Heuristics for Vietnamese bank and e-wallet payment success/confirmation screenshots.
class PaymentScreenshotParser {
  const PaymentScreenshotParser();

  static const List<String> _bankNames = [
    'Vietcombank',
    'Techcombank',
    'MB Bank',
    'MBBank',
    'VietinBank',
    'BIDV',
    'Agribank',
    'ACB',
    'VPBank',
    'TPBank',
    'Sacombank',
    'VIB',
    'OCB',
    'SHB',
    'Cake',
    'Timo',
    'HDBank',
    'MSB',
    'SeABank',
  ];

  static const List<String> _walletNames = [
    'MoMo',
    'ZaloPay',
    'Viettel Money',
    'VNPay',
    'ShopeePay',
  ];

  /// Checks if the text has strong signals of a bank or e-wallet transaction.
  bool isPaymentScreenshot(String rawText) {
    final folded = ReceiptParser.fold(rawText);

    final paymentKeywords = RegExp(
      r'\b(chuyen tien|chuyen khoan|giao dich|thanh toan|thanh cong|nguoi thu huong|tai khoan thu huong|ma giao dich|ma tra soat|so tien chuyen|vi dien tu|so du|bien lai dien tu)\b',
    );

    final hasProvider = [..._bankNames, ..._walletNames].any((name) =>
        folded.contains(ReceiptParser.fold(name)));

    return hasProvider || paymentKeywords.allMatches(folded).length >= 2;
  }

  ParsedPaymentScreenshot parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final foldedAll = ReceiptParser.fold(rawText);
    final provider = _detectProvider(foldedAll);
    final source = _detectSource(foldedAll, provider);
    final status = _detectStatus(foldedAll);
    final amount = _detectAmount(lines);
    final recipient = _detectRecipient(lines);
    final date = _detectDate(lines);
    final reference = _detectReference(lines);
    final note = _detectNote(lines);
    final category = _suggestCategory(recipient, note, rawText);

    return ParsedPaymentScreenshot(
      source: source,
      provider: provider,
      recipient: recipient,
      amount: amount,
      date: date,
      status: status,
      transactionReference: reference,
      note: note,
      suggestedCategory: category,
    );
  }

  String? _detectProvider(String foldedAll) {
    for (final wallet in _walletNames) {
      if (foldedAll.contains(ReceiptParser.fold(wallet))) {
        return wallet;
      }
    }
    for (final bank in _bankNames) {
      if (foldedAll.contains(ReceiptParser.fold(bank))) {
        return bank;
      }
    }
    return null;
  }

  ExpenseSource _detectSource(String foldedAll, String? provider) {
    if (provider != null) {
      if (_walletNames.contains(provider)) {
        return ExpenseSource.eWallet;
      }
      return ExpenseSource.bankTransfer;
    }
    if (RegExp(r'\b(momo|zalopay|viettel money|vnpay|shopeepay)\b').hasMatch(foldedAll)) {
      return ExpenseSource.eWallet;
    }
    return ExpenseSource.bankTransfer;
  }

  PaymentStatus _detectStatus(String foldedAll) {
    if (RegExp(r'\b(that bai|khong thanh cong|bi huy|loi giao dich|failed|unsuccessful|cancelled)\b')
        .hasMatch(foldedAll)) {
      return PaymentStatus.failed;
    }
    if (RegExp(r'\b(dang xu ly|cho xu ly|dang cho|pending|processing|in progress)\b')
        .hasMatch(foldedAll)) {
      return PaymentStatus.pending;
    }
    if (RegExp(r'\b(thanh cong|hoan tat|successful|success|completed|da chuyen)\b')
        .hasMatch(foldedAll)) {
      return PaymentStatus.successful;
    }
    return PaymentStatus.unknown;
  }

  double? _detectAmount(List<String> lines) {
    final amountLabel = RegExp(
      r'\b(so tien chuyen|so tien giao dich|so tien|amount|gia tri|so tien thanh toan)\b',
    );
    final currencyTail = RegExp(r'(?:vnd|vnđ|đ|₫)$', caseSensitive: false);

    // 1. Scan labelled lines first
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final folded = ReceiptParser.fold(line);

      if (amountLabel.hasMatch(folded)) {
        // Try same line
        final moneyMatches = RegExp(r'[-+]?\s*(\d{1,3}(?:[., ]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)')
            .allMatches(line);
        for (final m in moneyMatches) {
          final val = ReceiptParser.parseAmount(m.group(1)!);
          if (val != null && val > 0) return val;
        }

        // Try next line if standalone
        if (i + 1 < lines.length) {
          final next = lines[i + 1];
          final val = ReceiptParser.parseAmount(next);
          if (val != null && val > 0) return val;
        }
      }
    }

    // 2. Scan lines with VND/đ suffix
    for (final line in lines) {
      if (currencyTail.hasMatch(line.trim())) {
        final val = ReceiptParser.parseAmount(line);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  String? _detectRecipient(List<String> lines) {
    final recipientLabels = RegExp(
      r'\b(nguoi nhan|nguoi thu huong|tai khoan thu huong|ten nguoi nhan|thanh toan cho|dich vu|den|to|beneficiary|recipient)\b',
    );
    final excluded = RegExp(
      r'\b(ngan hang|so tai khoan|ngay|gio|ma giao dich|noi dung|loi nhan|vnd|phi|chi tiet)\b',
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final folded = ReceiptParser.fold(line);

      if (recipientLabels.hasMatch(folded)) {
        // Look after the label on the same line
        final match = recipientLabels.firstMatch(folded)!;
        final candidate = line.substring(match.end).replaceAll(RegExp(r'^[:\-\s]+'), '').trim();
        if (candidate.isNotEmpty && !excluded.hasMatch(ReceiptParser.fold(candidate))) {
          return candidate;
        }

        // Or look at the next line
        if (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          final nextFolded = ReceiptParser.fold(next);
          if (next.isNotEmpty &&
              !excluded.hasMatch(nextFolded) &&
              !recipientLabels.hasMatch(nextFolded) &&
              !RegExp(r'^\d+$').hasMatch(next)) {
            return next;
          }
        }
      }
    }

    // Fallback: look for uppercase Vietnamese names like "NGUYEN VAN A"
    for (final line in lines) {
      if (RegExp(r'^[A-ZÀ-Ỹ\s]{5,40}$').hasMatch(line) &&
          !RegExp(r'\b(VIETCOMBANK|TECHCOMBANK|MBBANK|BIDV|AGRIBANK|THANH CONG|GIAO DICH|SO TIEN)\b')
              .hasMatch(line)) {
        return line;
      }
    }

    return null;
  }

  DateTime? _detectDate(List<String> lines) {
    final dateRegex = RegExp(
      r'\b(?:\d{1,2}[/.-]\d{1,2}[/.-]\d{4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2})\b',
    );

    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        final parsed = ReceiptParser.parseDate(match.group(0)!);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? _detectReference(List<String> lines) {
    final refLabels = RegExp(
      r'\b(ma giao dich|ma tra soat|ma tham chieu|so giao dich|so tham chieu|ma gd|magd|ref|transaction id)\b',
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final folded = ReceiptParser.fold(line);

      if (refLabels.hasMatch(folded)) {
        final match = refLabels.firstMatch(folded)!;
        final candidate = line.substring(match.end).replaceAll(RegExp(r'^[:\-\s]+'), '').trim();
        if (candidate.isNotEmpty && candidate.length >= 4) {
          return candidate.split(' ').first;
        }

        if (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (next.isNotEmpty && next.length >= 4 && !next.contains(' ')) {
            return next;
          }
        }
      }
    }
    return null;
  }

  String? _detectNote(List<String> lines) {
    final noteLabels = RegExp(
      r'\b(noi dung|loi nhan|message|note|noi dung chuyen tien|nd)\b',
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final folded = ReceiptParser.fold(line);

      if (noteLabels.hasMatch(folded)) {
        final match = noteLabels.firstMatch(folded)!;
        final candidate = line.substring(match.end).replaceAll(RegExp(r'^[:\-\s]+'), '').trim();
        if (candidate.isNotEmpty) return candidate;

        if (i + 1 < lines.length) {
          return lines[i + 1].trim();
        }
      }
    }
    return null;
  }

  String? _suggestCategory(String? recipient, String? note, String rawText) {
    final combined = ReceiptParser.fold('${recipient ?? ''} ${note ?? ''} $rawText');
    if (combined.trim().isEmpty) return null;

    if (RegExp(r'\b(an|com|cafe|coffee|tra|milk tea|food|highlands|phuc long|bun|pho|lau|quan an|nha hang|banh)\b')
        .hasMatch(combined)) {
      return 'Food';
    }
    if (RegExp(r'\b(hoc|sach|khoa hoc|course|tuition|hoc phi|fahasa|book|truong|lop|giao trinh)\b')
        .hasMatch(combined)) {
      return 'Study';
    }
    if (RegExp(r'\b(grab[a-z]*|be|gojek|xang|petrolimex|taxi|ve xe|bus|ve may bay|vietnam airlines|flight|chuyen xe)\b')
        .hasMatch(combined)) {
      return 'Travel';
    }
    if (RegExp(r'\b(the gioi di dong|tgdd|fpt|phong vu|laptop|chuot|ban phim|dien thoai|gear|apple|pc)\b')
        .hasMatch(combined)) {
      return 'Gear';
    }
    if (RegExp(r'\b(cgv|cinema|lotte|rap|ve xem phim|game|steam|karaoke|billiards|ve vao cong)\b')
        .hasMatch(combined)) {
      return 'Entertainment';
    }
    return null;
  }
}
