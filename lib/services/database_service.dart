import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/category_mapper.dart';
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
          // Create Base_Sheet table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS Base_Sheet (
              Badge_NO TEXT PRIMARY KEY,
              Employee_Name TEXT,
              Bus_Line TEXT,
              Depart_Text TEXT,
              Grade TEXT,
              Basic TEXT,
              Appraisal5 TEXT,
              pay_scale_area_text TEXT,
              upload_date TEXT
            )
          ''');

          // Create grade_changes table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS grade_changes (
              badge_no TEXT PRIMARY KEY,
              new_grade TEXT,
              changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          // Create Adjustments table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS Adjustments (
              Badge_NO TEXT PRIMARY KEY,
              Adjustments TEXT
            )
          ''');
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

  /// Check if all required tables exist for a specific category
  static Future<Map<String, bool>> checkCategoryTablesExist(
    Database db,
    String category,
  ) async {
    final tables = await getAvailableTables(db);
    final salaryScaleTable = CategoryMapper.getSalaryScaleTable(category);
    final annualIncreaseTable = CategoryMapper.getAnnualIncreaseTable(category);

    return {
      'salaryScale': tables.contains(salaryScaleTable),
      'annualIncrease': tables.contains(annualIncreaseTable),
    };
  }

  /// Check if all required tables exist for all categories
  static Future<Map<String, Map<String, bool>>> checkAllCategoryTablesExist(
    Database db,
  ) async {
    final result = <String, Map<String, bool>>{};

    for (final category in CategoryMapper.getAllCategories()) {
      result[category] = await checkCategoryTablesExist(db, category);
    }

    return result;
  }

  /// Check if a table exists and has data
  static Future<bool> tableHasData(Database db, String tableName) async {
    try {
      // First check if table exists
      final tables = await getAvailableTables(db);
      if (!tables.contains(tableName)) {
        return false;
      }

      // Check if table has any data
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM "$tableName"',
      );
      final count = result.first['count'] as int;
      return count > 0;
    } catch (e) {
      // If there's an error (table doesn't exist, etc.), return false
      return false;
    }
  }
}
