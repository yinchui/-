import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  const DatabaseSchema._();

  static const version = 2;

  static const createStatements = [
    '''
CREATE TABLE medications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  dosage TEXT NOT NULL,
  schedule TEXT NOT NULL,
  start_date TEXT,
  duration_days INTEGER,
  daily_plans TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''',
    '''
CREATE TABLE medication_logs (
  id TEXT PRIMARY KEY,
  medication_id TEXT NOT NULL,
  scheduled_time TEXT NOT NULL,
  confirmed_time TEXT,
  status TEXT NOT NULL CHECK (status IN ('confirmed', 'missed')),
  date TEXT NOT NULL,
  FOREIGN KEY (medication_id) REFERENCES medications (id) ON DELETE CASCADE
)
''',
    '''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('insert', 'update', 'delete')),
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0 CHECK (synced IN (0, 1))
)
''',
    '''
CREATE INDEX idx_medication_logs_date
ON medication_logs (date)
''',
    '''
CREATE INDEX idx_sync_queue_unsynced
ON sync_queue (synced, created_at)
''',
  ];

  static Future<void> upgrade(
    DatabaseExecutor database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await database.execute(
        'ALTER TABLE medications ADD COLUMN start_date TEXT',
      );
      await database.execute(
        'ALTER TABLE medications ADD COLUMN duration_days INTEGER',
      );
      await database.execute(
        "ALTER TABLE medications ADD COLUMN daily_plans TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }
}
