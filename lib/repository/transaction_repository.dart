import '../database/app_database.dart';
import '../models/transaction_model.dart';

/// Local transaction operations. Nothing is saved until insertion is requested.
class TransactionRepository {
  TransactionRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  static const _orderBy = 'date DESC, id DESC';

  /// Inserts a new record and returns its generated ID without mutating [record].
  Future<int> insertTransaction(TransactionModel record) async {
    if (record.id != null) {
      throw ArgumentError.value(record.id, 'id', 'New records must have no ID');
    }
    final db = await _database.database;
    return db.insert(AppDatabase.transactionsTable, record.toMap());
  }

  /// Returns the affected row count, or zero when the ID does not exist.
  Future<int> updateTransaction(TransactionModel record) async {
    final id = record.id;
    if (id == null) {
      throw ArgumentError.value(
        id,
        'id',
        'An update requires a saved record ID',
      );
    }
    final db = await _database.database;
    final values = record.toMap()..remove('id');
    return db.update(
      AppDatabase.transactionsTable,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes the database row only; receipt image ownership stays with services.
  Future<int> deleteTransaction(int id) async {
    final db = await _database.database;
    return db.delete(
      AppDatabase.transactionsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.transactionsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TransactionModel.fromMap(rows.first);
  }

  /// Newest transaction dates first, with descending IDs breaking date ties.
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.transactionsTable,
      orderBy: _orderBy,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Includes both boundary instants. Callers supply the exact end time; a date
  /// at midnight is not implicitly expanded to the end of that calendar day.
  Future<List<TransactionModel>> getTransactionsBetweenDates(
    DateTime start,
    DateTime end,
  ) async {
    if (start.isAfter(end)) {
      throw ArgumentError('The start date must not be after the end date');
    }
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.transactionsTable,
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        TransactionModel.encodeDateTime(start),
        TransactionModel.encodeDateTime(end),
      ],
      orderBy: _orderBy,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }
}
