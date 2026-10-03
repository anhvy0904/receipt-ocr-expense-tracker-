import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receiptwise/database/app_database.dart';
import 'package:receiptwise/repository/transaction_repository.dart';

import '../test/support/receipt_flow_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android SQLite and Provider review-to-analytics flow', (
    tester,
  ) async {
    final root = await (await getTemporaryDirectory()).createTemp(
      'receiptwise_integration_',
    );
    final database = AppDatabase(databasePath: '${root.path}/transactions.db');
    addTearDown(() async {
      await database.close();
      await root.delete(recursive: true);
    });
    await exerciseReceiptFlow(
      tester,
      repository: TransactionRepository(database: database),
      root: root,
    );
  });
}
