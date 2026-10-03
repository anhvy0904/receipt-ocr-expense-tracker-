import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Owns the application's SQLite connection and versioned schema.
///
/// The default instance opens lazily in sqflite's private database directory.
/// Tests can supply an independent factory and an in-memory or temporary path.
class AppDatabase {
  AppDatabase({this._factory, this._databasePath});

  static final instance = AppDatabase();
  static const databaseName = 'receiptwise.db';
  static const schemaVersion = 1;
  static const transactionsTable = 'transactions';

  final DatabaseFactory? _factory;
  final String? _databasePath;
  Future<Database>? _databaseFuture;
  Future<void>? _closing;

  Future<Database> get database async {
    final closing = _closing;
    if (closing != null) await closing;
    final pending = _databaseFuture ??= _openDatabase();
    try {
      return await pending;
    } catch (_) {
      // A failed open must not permanently prevent a later retry.
      if (identical(_databaseFuture, pending)) {
        _databaseFuture = null;
      }
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final factory = _factory ?? databaseFactory;
    final databasePath =
        _databasePath ??
        path.join(await factory.getDatabasesPath(), databaseName);

    return factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $transactionsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              merchant TEXT NOT NULL,
              amount REAL NOT NULL,
              date TEXT NOT NULL,
              category TEXT NOT NULL,
              receipt_image_path TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_transactions_date ON $transactionsTable (date)',
          );
        },
      ),
    );
  }

  /// Release the connection when no repository operations are in flight.
  /// A later request opens a fresh connection to the same database file.
  Future<void> close() {
    if (_closing != null) return _closing!;
    final operation = _closeDatabase();
    final completion = operation.whenComplete(() => _closing = null);
    _closing = completion;
    return completion;
  }

  Future<void> _closeDatabase() async {
    final pending = _databaseFuture;
    if (pending == null) return;
    Database db;
    try {
      db = await pending;
    } catch (_) {
      // No native connection exists after a failed open.
      if (identical(_databaseFuture, pending)) _databaseFuture = null;
      return;
    }
    await db.close();
    if (identical(_databaseFuture, pending)) {
      _databaseFuture = null;
    }
  }
}
