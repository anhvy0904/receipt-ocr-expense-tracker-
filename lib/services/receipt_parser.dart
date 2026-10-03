/// Best-effort local heuristics. Missing values stay null for manual review.
class ParsedReceipt {
  const ParsedReceipt({this.merchant, this.amount, this.date});
  final String? merchant;
  final double? amount;
  final DateTime? date;
}

class ReceiptParser {
  ParsedReceipt parse(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    String? merchant;
    double? amount;
    DateTime? date;
    final totals = RegExp(
      r'tổng\s*(cộng|tiền|thanh toán)|thành\s*tiền|grand\s*total|\btotal\b',
      caseSensitive: false,
    );
    final excluded = RegExp(
      r'hóa\s*đơn|hoá\s*đơn|receipt|invoice|địa\s*chỉ|điện\s*thoại|\btel\b|\bđt\b|\bphone\b|\bmst\b|mã\s*số\s*thuế|ngày|date|thu ngân|cashier',
      caseSensitive: false,
    );
    final dates = RegExp(r'\b\d{1,2}[/.-]\d{1,2}[/.-]\d{4}\b');
    final money = RegExp(
      r'-?\d+(?:[., ]\d{3})+(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?',
    );
    final currency = RegExp(
      r'(?<![\d.,])(-?\d{1,3}(?:[., ]\d{3})+(?:[.,]\d{1,2})?|-?\d+(?:[.,]\d{1,2})?)\s*(?:vnd|vnđ|đ|₫)',
      caseSensitive: false,
    );
    double? currencyFallback;
    for (final line in lines) {
      for (final match in dates.allMatches(line)) {
        date ??= parseDate(match.group(0)!);
      }
      final totalLabel = totals.firstMatch(line);
      if (totalLabel != null) {
        final candidates = money.allMatches(line.substring(totalLabel.end));
        for (final match in candidates) {
          final value = parseAmount(match.group(0)!);
          if (value != null && value > 0) {
            amount = value;
            break;
          }
        }
      } else if (currency.hasMatch(line) && !dates.hasMatch(line)) {
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
          merchantCandidate(line, totals, excluded, dates, currency)) {
        merchant = line;
      }
    }
    return ParsedReceipt(
      merchant: merchant,
      amount: amount ?? currencyFallback,
      date: date,
    );
  }

  bool merchantCandidate(
    String line,
    RegExp totals,
    RegExp excluded,
    RegExp dates,
    RegExp currency,
  ) {
    return !totals.hasMatch(line) &&
        !excluded.hasMatch(line) &&
        !dates.hasMatch(line) &&
        !currency.hasMatch(line) &&
        RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(line) &&
        !RegExp(r'^\d|https?://|www\.', caseSensitive: false).hasMatch(line);
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

  /// Strict day/month/year validation; DateTime normalization is rejected.
  static DateTime? parseDate(String input) {
    final match = RegExp(
      r'^(\d{1,2})([/.-])(\d{1,2})\2(\d{4})$',
    ).firstMatch(input.trim());
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[3]!);
    final year = int.parse(match[4]!);
    if (year < 1 || month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().padLeft(4, '0')}';
}
