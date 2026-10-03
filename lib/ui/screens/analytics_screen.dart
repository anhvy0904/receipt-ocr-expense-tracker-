import 'package:flutter/material.dart';

import '../../models/spending_analytics.dart';
import '../../services/analytics_service.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/placeholder_content.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    this.service,
    this.active = true,
    this.revision = 0,
    super.key,
  });
  final AnalyticsService? service;
  final bool active;
  final int revision;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final _service = widget.service ?? AnalyticsService();
  SpendingAnalytics? _data;
  bool _loading = false;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active || oldWidget.revision != widget.revision)) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await _service.load();
      if (mounted && request == _request) setState(() => _data = data);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return TickerMode(
      enabled: widget.active,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Expense analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh analytics',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? PlaceholderContent(
                    icon: Icons.error_outline,
                    title: 'Could not load analytics',
                    description: 'Please try again.',
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  )
                : data == null || data.transactionCount == 0
                ? const PlaceholderContent(
                    icon: Icons.insights_outlined,
                    title: 'No transactions yet',
                    description:
                        'Save a receipt to see your spending breakdown.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CategoryDonutChart(data: data),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(),
                          ),
                          WeeklyBarChart(data: data),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
