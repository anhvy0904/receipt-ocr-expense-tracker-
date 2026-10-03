import '../models/home_summary.dart';
import '../repository/transaction_repository.dart';
import 'analytics_service.dart';

/// Uses the same calendar-day and money aggregation rules as Analytics.
class HomeSummaryService {
  HomeSummaryService({TransactionRepository? repository})
    : _repository = repository ?? TransactionRepository();

  final TransactionRepository _repository;

  Future<HomeSummary> load({DateTime? now}) async {
    final records = await _repository.getAllTransactions();
    final analytics = AnalyticsService.aggregate(
      records,
      now: now ?? DateTime.now(),
    );
    return HomeSummary(
      totalCents: analytics.totalCents,
      weeklyCents: analytics.days.fold(
        BigInt.zero,
        (sum, day) => sum + day.cents,
      ),
      transactionCount: records.length,
      recentTransactions: records.take(3).toList(),
    );
  }
}
