import 'transaction_model.dart';

class HomeSummary {
  HomeSummary({
    required this.totalCents,
    required this.weeklyCents,
    required this.transactionCount,
    required List<TransactionModel> recentTransactions,
  }) : recentTransactions = List.unmodifiable(recentTransactions);

  final BigInt totalCents;
  final BigInt weeklyCents;
  final int transactionCount;
  final List<TransactionModel> recentTransactions;
}
