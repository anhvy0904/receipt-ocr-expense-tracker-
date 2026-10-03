class CategorySpending {
  const CategorySpending({
    required this.category,
    required this.cents,
    required this.fraction,
  });
  final String category;
  final BigInt cents;
  final double fraction;
}

class DailySpending {
  const DailySpending({
    required this.date,
    required this.cents,
    required this.heightFraction,
  });
  final DateTime date;
  final BigInt cents;
  final double heightFraction;
}

class SpendingAnalytics {
  SpendingAnalytics({
    required this.transactionCount,
    required this.totalCents,
    required this.weeklyMaximumCents,
    required List<CategorySpending> categories,
    required List<DailySpending> days,
  }) : categories = List.unmodifiable(categories),
       days = List.unmodifiable(days);
  final int transactionCount;
  final BigInt totalCents;
  final BigInt weeklyMaximumCents;
  final List<CategorySpending> categories;
  final List<DailySpending> days;
}
