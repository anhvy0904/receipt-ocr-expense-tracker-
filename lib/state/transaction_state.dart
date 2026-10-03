import 'package:flutter/foundation.dart';

import '../models/home_summary.dart';
import '../models/spending_analytics.dart';
import '../models/transaction_model.dart';
import '../repository/transaction_repository.dart';
import '../services/analytics_service.dart';
import '../services/receipt_image_service.dart';
import '../services/receipt_save_service.dart';
import '../services/transaction_management_service.dart';

/// Provider's shared SQLite snapshot. Services own writes; widgets own only UI state.
class TransactionState extends ChangeNotifier {
  TransactionState({
    TransactionRepository? repository,
    ReceiptImageService? images,
    DateTime Function()? now,
  }) : repository = repository ?? TransactionRepository(),
       images = images ?? ReceiptImageService(),
       _now = now ?? DateTime.now;

  final TransactionRepository repository;
  final ReceiptImageService images;
  final DateTime Function() _now;
  late final saveService = ReceiptSaveService(
    repository: repository,
    images: images,
    onChanged: refresh,
  );
  late final managementService = TransactionManagementService(
    repository: repository,
    images: images,
    onChanged: refresh,
  );
  List<TransactionModel> _records = const [];
  List<TransactionModel> get records => _records;
  SpendingAnalytics? analytics;
  HomeSummary? homeSummary;
  bool loading = false;
  bool failed = false;
  int revision = 0;
  int _request = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    if (_disposed) return;
    final request = ++_request;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final records = await repository.getAllTransactions();
      if (_disposed || request != _request) return;
      _records = List.unmodifiable(records);
      final data = AnalyticsService.aggregate(records, now: _now());
      analytics = data;
      homeSummary = HomeSummary(
        totalCents: data.totalCents,
        weeklyCents: data.days.fold(BigInt.zero, (sum, day) => sum + day.cents),
        transactionCount: records.length,
        recentTransactions: records.take(3).toList(),
      );
      revision++;
    } catch (_) {
      if (!_disposed && request == _request) failed = true;
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
