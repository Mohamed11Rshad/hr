import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // For getApplicationDocumentsDirectory
import 'dart:io'; // For Directory

class DatabaseService {
  static const String _dbName = 'hr_database.db';

  // Existing method to open database (likely uses a default path)
  static Future<Database> openDatabase() async {
    sqfliteFfiInit(); // Initialize FFI
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1, // Define your DB version
        onCreate: (db, version) async {
          // Schema creation logic if any (e.g., initial tables)
        },
      ),
    );
  }

  // New method to get the database path
  static Future<String> getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _dbName);
  }

  // New method to open a database at a specific path (for isolates)
  static Future<Database> openDatabaseWithPath(String path) async {
    sqfliteFfiInit(); // Initialize FFI
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1, // Ensure version matches
        onCreate: (db, version) async {
          // Schema creation logic if any
        },
      ),
    );
  }

  static Future<List<String>> getAvailableTables(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata'",
    );
    return tables.map((row) => row['name'] as String).toList();
  }
}
