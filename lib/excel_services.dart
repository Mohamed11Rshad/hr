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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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

    // Add current date and time with custom format
    final now = DateTime.now();
    // Format: YYYY-M-D h:mmAM/PM (e.g., 2025-4-5 5:37PM)
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final formattedDate =
        '${now.year}-${now.month}-${now.day} $hour:${now.minute.toString().padLeft(2, '0')}${now.hour >= 12 ? "pm" : "am"}';

    for (int i = 1; i < rows.length; i++) {
      final values = <String, dynamic>{
        'upload_date': formattedDate, // Add formatted upload date to each row
      };
      bool hasData = false;

      for (int j = 0; j < headers.length && j < rows[i].length; j++) {
        final value = rows[i][j]?.value?.toString();
        if (value != null) {
          values[_escapeColumnName(headers[j])] = value;
          hasData = true;
        }
      }

      if (hasData) {
        batch.insert(tableName, values);
        insertedCount++;
      }
    }

    await batch.commit(noResult: true);
    return insertedCount;
  }

  List<String> _processHeaders(List<Data?> headerRow) {
    return headerRow
        .map((cell) => cell?.value.toString().trim() ?? '')
        .where((header) => header.isNotEmpty)
        .toList();
  }

  String _escapeColumnName(String name) => '"${name.replaceAll('"', '""')}"';
}
