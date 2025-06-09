import 'dart:io';
import 'package:excel/excel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ConfigSheetService {
  final Database db;

  ConfigSheetService(this.db);

  Future<String> processConfigSheet(File file, String sheetName) async {
    try {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Check if the sheet with the specified name exists
      if (!excel.tables.containsKey(sheetName)) {
        return 'خطأ: لا يوجد Sheet باسم "$sheetName" في الملف';
      }

      final sheet = excel.tables[sheetName]!;
      final rows = sheet.rows;
      if (rows.isEmpty) {
        return 'خطأ: Sheet "$sheetName" فارغة';
      }

      // Get header row
      final headerRow = rows[0];
      final headers = <String>[];

      // Process headers
      for (var cell in headerRow) {
        final header = cell?.value.toString().trim() ?? '';
        if (header.isNotEmpty) {
          headers.add(header);
        }
      }

      if (headers.isEmpty) {
        return 'خطأ: لا توجد عناوين في sheet "$sheetName"';
      }

      // Check for duplicate headers
      final uniqueHeaders = headers.toSet();
      if (uniqueHeaders.length != headers.length) {
        return 'خطأ: يوجد عناوين مكررة في sheet "$sheetName"';
      }

      // Create a valid table name by replacing spaces with underscores
      final tableName = sheetName.replaceAll(' ', '_');

      // Check if table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [tableName],
      );

      // If table exists, drop it
      if (tables.isNotEmpty) {
        await db.execute('DROP TABLE "$tableName"');
      }

      // Create table
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

      // Insert data
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final values = <String, dynamic>{};

        // Skip empty rows
        bool isEmpty = true;
        for (var cell in row) {
          if (cell?.value != null) {
            isEmpty = false;
            break;
          }
        }
        if (isEmpty) continue;

        // Process row data
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final cell = row[j];
          final value = cell?.value?.toString() ?? '';
          values[headers[j]] = value;
        }

        values['upload_date'] = now;
        batch.insert(tableName, values);
      }

      // Execute batch
      await batch.commit();

      return 'تم إضافة بيانات "$sheetName" بنجاح';
    } catch (e) {
      return 'خطأ في معالجة الملف: ${e.toString()}';
    }
  }

  String _escapeColumnName(String name) {
    // Sanitize column name for SQLite
    final sanitized = name.replaceAll('"', '""');
    return '"$sanitized"';
  }
}
