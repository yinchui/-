import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get instance => database;

  Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return existingDatabase;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(
      documentsDirectory.path,
      'medication_reminder.sqlite',
    );
    final openedDatabase = await openDatabase(
      databasePath,
      version: DatabaseSchema.version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        for (final statement in DatabaseSchema.createStatements) {
          await database.execute(statement);
        }
      },
      onUpgrade: DatabaseSchema.upgrade,
    );

    _database = openedDatabase;
    return openedDatabase;
  }

  Future<void> close() async {
    final existingDatabase = _database;
    if (existingDatabase == null) {
      return;
    }

    await existingDatabase.close();
    _database = null;
  }
}
