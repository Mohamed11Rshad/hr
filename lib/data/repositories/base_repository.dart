import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/utils/validation_utils.dart';

abstract class BaseRepository {
  final Database db;
  
  BaseRepository(this.db);
  
  /// Gets the badge column name from the specified table
  Future<String> getBadgeColumnName(String tableName) async {
    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info("$tableName")');
      final columns = tableInfo.map((col) => col['name'].toString()).toList();
      return ValidationUtils.findBadgeColumn(columns);
    } catch (e) {
      return 'Badge_NO'; // Default fallback
    }
  }
  
  /// Gets the employee name column from the specified table
  Future<String> getEmployeeNameColumn(String tableName) async {
    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info("$tableName")');
      final columns = tableInfo.map((col) => col['name'].toString()).toList();
      return ValidationUtils.findEmployeeNameColumn(columns);
    } catch (e) {
      return 'Employee_Name'; // Default fallback
    }
  }
  
  /// Checks if a table exists in the database
  Future<bool> tableExists(String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Gets all column names from a table
  Future<List<String>> getTableColumns(String tableName) async {
    try {
      final tableInfo = await db.rawQuery('PRAGMA table_info("$tableName")');
      return tableInfo.map((col) => col['name'].toString()).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Executes a query with error handling
  Future<List<Map<String, dynamic>>> executeQuery(
    String query, [
    List<dynamic>? arguments,
  ]) async {
    try {
      return await db.rawQuery(query, arguments);
    } catch (e) {
      print('Database query error: $e');
      rethrow;
    }
  }
  
  /// Executes a batch operation with error handling
  Future<List<dynamic>> executeBatch(Batch batch) async {
    try {
      return await batch.commit();
    } catch (e) {
      print('Database batch error: $e');
      rethrow;
    }
  }
}
