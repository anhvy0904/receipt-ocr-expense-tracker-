import '../models/receipt_review_draft.dart';
import '../models/spending_analytics.dart';
import '../models/transaction_model.dart';
import '../repository/transaction_repository.dart';

class AnalyticsService {
  AnalyticsService({TransactionRepository? repository})
    : _repository = repository ?? TransactionRepository();
  final TransactionRepository _repository;

  Future<SpendingAnalytics> load({DateTime? now}) async => aggregate(
    await _repository.getAllTransactions(),
    now: now ?? DateTime.now(),
  );

  /// Use integer cents to avoid overflowing totals or passing infinity to Canvas.
  static SpendingAnalytics aggregate(
    List<TransactionModel> records, {
    required DateTime now,
  }) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day - 6 + index),
    );
    final categories = {
      for (final category in ReceiptReviewDraft.categories)
        category: BigInt.zero,
    };
    final daily = List.filled(7, BigInt.zero);
    for (final record in records) {
      final cents = amountToCents(record.amount);
      final category = categories.containsKey(record.category)
          ? record.category
          : 'Other';
      categories[category] = categories[category]! + cents;
      final date = record.date.toLocal();
      for (var index = 0; index < days.length; index++) {
        if (date.year == days[index].year &&
            date.month == days[index].month &&
            date.day == days[index].day) {
          daily[index] += cents;
          break;
        }
      }
    }
    final total = categories.values.fold(
      BigInt.zero,
      (sum, amount) => sum + amount,
    );
    final maximum = daily.fold(
      BigInt.zero,
      (max, amount) => amount > max ? amount : max,
    );
    return SpendingAnalytics(
      transactionCount: records.length,
      totalCents: total,
      weeklyMaximumCents: maximum,
      categories: categories.entries
          .map(
            (entry) => CategorySpending(
              category: entry.key,
              cents: entry.value,
              fraction: fraction(entry.value, total),
            ),
          )
          .toList(),
      days: List.generate(
        7,
        (index) => DailySpending(
          date: days[index],
          cents: daily[index],
          heightFraction: fraction(daily[index], maximum),
        ),
      ),
    );
  }

  static double fraction(BigInt amount, BigInt total) {
    if (total == BigInt.zero) return 0;
    final scale = BigInt.from(1000000000000000);
    return ((amount * scale) ~/ total).toDouble() / scale.toDouble();
  }

  static BigInt amountToCents(double amount) {
    if (!amount.isFinite || amount <= 0) return BigInt.zero;
    final parts = amount.toString().toLowerCase().split('e');
    final mantissa = parts[0].split('.');
    final digits = BigInt.parse(mantissa.join());
    final shift =
        (parts.length == 2 ? int.parse(parts[1]) : 0) +
        2 -
        (mantissa.length == 2 ? mantissa[1].length : 0);
    if (shift >= 0) return digits * BigInt.from(10).pow(shift);
    final divisor = BigInt.from(10).pow(-shift);
    return (digits + divisor ~/ BigInt.two) ~/ divisor;
  }
}
