import '../models/expense_source.dart';
import 'payment_screenshot_parser.dart';

/// Best-effort local heuristics. Missing values stay null for manual review.
class ParsedReceipt {
  const ParsedReceipt({
    this.merchant,
    this.amount,
    this.date,
    this.source = ExpenseSource.receipt,
    this.status = PaymentStatus.unknown,
    this.provider,
    this.transactionReference,
    this.note,
    this.suggestedCategory,
  });

  final String? merchant;
  final double? amount;
  final DateTime? date;
  final ExpenseSource source;
  final PaymentStatus status;
  final String? provider;
  final String? transactionReference;
  final String? note;
  final String? suggestedCategory;
}

class ReceiptParser {
  static String fold(String value) => _fold(value);

  static String _fold(String value) {
    var result = value.toLowerCase();
    const accents = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final entry in accents.entries) {
      result = result.replaceAll(RegExp('[${entry.value}]'), entry.key);
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  ParsedReceipt parse(String text) {
    // 1. Detect if image is a bank or e-wallet payment confirmation
    const paymentParser = PaymentScreenshotParser();
    if (paymentParser.isPaymentScreenshot(text)) {
      final payment = paymentParser.parse(text);
      if (payment.amount != null || payment.recipient != null || payment.provider != null) {
        return ParsedReceipt(
          merchant: payment.recipient,
          amount: payment.amount,
          date: payment.date,
          source: payment.source,
          status: payment.status,
          provider: payment.provider,
          transactionReference: payment.transactionReference,
          note: payment.note,
          suggestedCategory: payment.suggestedCategory,
        );
      }
    }

    // 2. Physical receipt heuristics
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    String? merchant;
    double? amount;
    DateTime? date;
    final totals = RegExp(
      r'\b(?:tong (?:cong|tien|thanh toan)|thanh tien|thanh toan|cong tien|amount due|grand total|total)\b',
      caseSensitive: false,
    );
    final excluded = RegExp(
      r'\b(?:hoa don|receipt|invoice|dia chi|address|dien thoai|tel|dt|phone|mst|ma so thue|ngay|date|thu ngan|cashier)\b',
      caseSensitive: false,
    );
    final dates = RegExp(
      r'\b(?:\d{4}[/.-]\d{1,2}[/.-]\d{1,2}|\d{1,2}[/.-]\d{1,2}[/.-]\d{4})\b',
    );
    final money = RegExp(
      r'-?\d+(?:[., ]\d{3})+(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?',
    );
    final currency = RegExp(
      r'(?<![\d.,])(-?\d{1,3}(?:[., ]\d{3})+(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?)\s*(?:vnd|vnđ|đ|₫)',
      caseSensitive: false,
    );
    double? currencyFallback;
    int bestTotalScore = -1;
    int bestDateScore = -1;
    final nonTotals = RegExp(
      r'\b(?:subtotal|sub total|tam tinh|tien khach|khach dua|tien thua|change|cash|vat|tax|giam gia|discount)\b',
    );
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final folded = _fold(line);
      for (final match in dates.allMatches(line)) {
        final candidate = parseDate(match.group(0)!);
        final score = RegExp(r'\b(?:ngay|date)\b').hasMatch(folded) ? 1 : 0;
        if (candidate != null && score > bestDateScore) {
          date = candidate;
          bestDateScore = score;
        }
      }
      final totalLabel = nonTotals.hasMatch(folded)
          ? null
          : totals.firstMatch(folded);
      if (totalLabel != null) {
        // Match and slice the same normalized text so spacing cannot shift offsets.
        var amountText = folded.substring(totalLabel.end).trim();
        bool adjacent = false;
        if (!money.hasMatch(amountText) && index + 1 < lines.length) {
          final next = lines[index + 1];
          // Only consider a standalone number; labelled phone/date/item lines are skipped.
          if (RegExp(
                r'^\s*[:=]?\s*-?\d[\d., ]*\s*(?:vnd|vnđ|đ|₫)?\s*$',
                caseSensitive: false,
              ).hasMatch(next) &&
              !dates.hasMatch(next)) {
            amountText = next;
            adjacent = true;
          }
        }
        final priority =
            RegExp(
              r'\b(?:tong cong|tong tien|tong thanh toan|grand total|amount due)\b',
            ).hasMatch(folded)
            ? 4
            : folded.contains('thanh tien')
            ? 1
            : 2;
        final score = priority * 2 + (adjacent ? 0 : 1);
        final candidates = money.allMatches(amountText);
        for (final match in candidates) {
          final value = parseAmount(match.group(0)!);
          if (value != null && value > 0 && score >= bestTotalScore) {
            amount = value;
            bestTotalScore = score;
            break;
          }
        }
      } else if (!nonTotals.hasMatch(folded) &&
          currency.hasMatch(line) &&
          !dates.hasMatch(line)) {
        for (final match in currency.allMatches(line)) {
          final value = parseAmount(match.group(1)!);
          if (value != null &&
              value > 0 &&
              (currencyFallback == null || value > currencyFallback)) {
            currencyFallback = value;
          }
        }
      }
      if (merchant == null &&
          merchantCandidate(line, totals, excluded, dates, currency) &&
          !nonTotals.hasMatch(folded)) {
        merchant = line;
      }
    }
    return ParsedReceipt(
      merchant: merchant,
      amount: amount ?? currencyFallback,
      date: date,
      source: ExpenseSource.receipt,
      status: PaymentStatus.successful,
      suggestedCategory: _suggestReceiptCategory(merchant, text),
    );
  }

  bool merchantCandidate(
    String line,
    RegExp totals,
    RegExp excluded,
    RegExp dates,
    RegExp currency,
  ) {
    return !totals.hasMatch(_fold(line)) &&
        !excluded.hasMatch(_fold(line)) &&
        !dates.hasMatch(line) &&
        !currency.hasMatch(line) &&
        RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(line) &&
        !RegExp(r'^\d|https?://|www\.', caseSensitive: false).hasMatch(line);
  }

  static String? _suggestReceiptCategory(String? merchant, String rawText) {
    final combined = _fold('${merchant ?? ''} $rawText');
    if (RegExp(r'\b(an|com|cafe|coffee|tra|highlands|phuc long|food|bun|pho|quan|nha hang|banh)\b')
        .hasMatch(combined)) {
      return 'Food';
    }
    if (RegExp(r'\b(hoc|sach|khoa hoc|course|tuition|fahasa|book|giao trinh|van phong pham)\b')
        .hasMatch(combined)) {
      return 'Study';
    }
    if (RegExp(r'\b(grab|be|gojek|xang|petrolimex|taxi|ve xe|bus|flight|travel)\b')
        .hasMatch(combined)) {
      return 'Travel';
    }
    if (RegExp(r'\b(the gioi di dong|fpt|phong vu|laptop|gear|dien thoai|chuot|ban phim)\b')
        .hasMatch(combined)) {
      return 'Gear';
    }
    if (RegExp(r'\b(cgv|cinema|lotte|rap|movie|karaoke|game|ticket)\b')
        .hasMatch(combined)) {
      return 'Entertainment';
    }
    return null;
  }

  /// Accept grouping separators used by Vietnamese receipts and a decimal tail.
  static double? parseAmount(String input) {
    var value = input.trim().replaceAll(RegExp(r'\s+'), '');
    value = value
        .replaceAll(RegExp(r'(VND|VNĐ|đ|₫)$', caseSensitive: false), '')
        .trim();
    if (RegExp(r'^\d{1,3}(?:[.,]\d{3})+$').hasMatch(value)) {
      value = value.replaceAll(RegExp(r'[.,]'), '');
    } else if (RegExp(r'^\d{1,3}(?:[.,]\d{3})+[.,]\d{1,2}$').hasMatch(value)) {
      final split = value.lastIndexOf(RegExp(r'[.,]'));
      value =
          '${value.substring(0, split).replaceAll(RegExp(r'[.,]'), '')}.${value.substring(split + 1)}';
    } else if (RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value)) {
      value = value.replaceAll(',', '.');
    } else {
      return null;
    }
    final amount = double.tryParse(value);
    return amount != null && amount.isFinite ? amount : null;
  }

  /// Strict day-first or year-first validation; DateTime normalization is rejected.
  static DateTime? parseDate(String input) {
    final value = input.trim();
    final match = RegExp(
      r'^(\d{1,2})([/.-])(\d{1,2})\2(\d{4})$',
    ).firstMatch(value);
    final iso = RegExp(
      r'^(\d{4})([/.-])(\d{1,2})\2(\d{1,2})$',
    ).firstMatch(value);
    if (match == null && iso == null) return null;
    final day = int.parse(match != null ? match[1]! : iso![4]!);
    final month = int.parse(match != null ? match[3]! : iso![3]!);
    final year = int.parse(match != null ? match[4]! : iso![1]!);
    if (year < 1 || month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().padLeft(4, '0')}';
}
