import 'dart:io';
import 'package:excel/excel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ExcelService {
  final Database db;

  ExcelService(this.db);

  Future<String> processExcelFile(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    String result = '';

    for (var sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      final headers = _processHeaders(rows[0]);
      if (headers.isEmpty) continue;

      final tableName = sheetName;
      await _clearAndCreateTable(tableName, headers);

      await _insertData(tableName, rows, headers);
      result = 'تمت الإضافة لجدول "$tableName"';
      break; // Only process first sheet
    }
    return result;
  }

  Future<void> _clearAndCreateTable(
    String tableName,
    List<String> headers,
  ) async {
    await db.execute('DROP TABLE IF EXISTS "$tableName"');
    final columns = headers
        .map((h) => '${_escapeColumnName(h)} TEXT')
        .join(', ');
    await db.execute('''
      CREATE TABLE "$tableName" (
        $columns,
        upload_date TEXT
      )
    ''');
  }

  Future<int> _insertData(
    String tableName,
    List<List<Data?>> rows,
    List<String> headers,
  ) async {
    final batch = db.batch();
    int insertedCount = 0;
    final existingRecords = await _getExistingRecords(tableName);

    // Add current date and time with custom format
    final now = DateTime.now();
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final formattedDate =
        '${now.year}-${now.month}-${now.day} $hour:${now.minute.toString().padLeft(2, '0')}${now.hour >= 12 ? "pm" : "am"}';

    for (int i = 1; i < rows.length; i++) {
      final values = <String, dynamic>{'upload_date': formattedDate};
      bool hasData = false;

      // Build record from row
      for (int j = 0; j < headers.length && j < rows[i].length; j++) {
        final value = rows[i][j]?.value?.toString();
        if (value != null) {
          values[_escapeColumnName(headers[j])] = value;
          hasData = true;
        }
      }

      if (hasData && !_isDuplicate(values, existingRecords)) {
        batch.insert(tableName, values);
        insertedCount++;
      }
    }

    await batch.commit(noResult: true);
    return insertedCount;
  }

  // Add these helper methods
  Future<List<Map<String, dynamic>>> _getExistingRecords(
    String tableName,
  ) async {
    return await db.query(tableName);
  }

  bool _isDuplicate(
    Map<String, dynamic> newRecord,
    List<Map<String, dynamic>> existingRecords,
  ) {
    for (final existingRecord in existingRecords) {
      bool isDuplicate = true;

      for (final key in newRecord.keys) {
        if (key == 'upload_date') continue; // Skip upload_date comparison

        if (newRecord[key]?.toString() != existingRecord[key]?.toString()) {
          isDuplicate = false;
          break;
        }
      }

      if (isDuplicate) return true;
    }

    return false;
  }

  List<String> _processHeaders(List<Data?> headerRow) {
    return headerRow
        .map((cell) => cell?.value.toString().trim() ?? '')
        .where((header) => header.isNotEmpty)
        .toList();
  }

  String _escapeColumnName(String name) => '"${name.replaceAll('"', '""')}"';
}
