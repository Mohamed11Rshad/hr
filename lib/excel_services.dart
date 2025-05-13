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

      // Check if table exists, create it if it doesn't
      await _createTableIfNotExists(tableName, headers);

      // Insert data without clearing the table first
      final insertedCount = await _insertData(tableName, rows, headers);
      result = 'تمت الإضافة لجدول "$tableName" المضاف: $insertedCount';
      break; // Only process first sheet
    }
    return result;
  }

  // New method to create table only if it doesn't exist
  Future<void> _createTableIfNotExists(
    String tableName,
    List<String> headers,
  ) async {
    // Check if table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [tableName],
    );

    if (tables.isEmpty) {
      // Table doesn't exist, create it
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
    } else {
      // Table exists, check if we need to add new columns
      final existingColumns = await db.rawQuery(
        'PRAGMA table_info("$tableName")',
      );
      final existingColumnNames =
          existingColumns.map((col) => col['name'].toString()).toList();

      // Add any missing columns
      for (final header in headers) {
        final escapedName = _escapeColumnName(header);
        final sanitizedName = escapedName.replaceAll('"', '');
        if (!existingColumnNames.contains(sanitizedName)) {
          await db.execute(
            'ALTER TABLE "$tableName" ADD COLUMN $escapedName TEXT',
          );
        }
      }
    }
  }

  // Replace the old _clearAndCreateTable method with the one above

  Future<int> _insertData(
    String tableName,
    List<List<Data?>> rows,
    List<String> headers,
  ) async {
    final batch = db.batch();
    int insertedCount = 0;
    final existingRecords = await _getExistingRecords(tableName);

    // Find the Badge NO column index
    final badgeNoIndex = headers.indexWhere(
      (header) => header.toLowerCase().contains('badge'),
    );

    // Add current date and time with custom format
    final now = DateTime.now();
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final formattedDate =
        '${now.year}-${now.month}-${now.day} $hour:${now.minute.toString().padLeft(2, '0')}${now.hour >= 12 ? "pm" : "am"}';

    // Group existing records by Badge NO for faster lookup
    final Map<String, List<Map<String, dynamic>>> existingByBadgeNo = {};
    String? badgeNoColumnSanitized;

    if (badgeNoIndex >= 0) {
      final badgeNoColumn = headers[badgeNoIndex];
      badgeNoColumnSanitized = _escapeColumnName(
        badgeNoColumn,
      ).replaceAll('"', '');

      for (final record in existingRecords) {
        final badgeNo = record[badgeNoColumnSanitized]?.toString() ?? '';
        if (badgeNo.isNotEmpty) {
          existingByBadgeNo.putIfAbsent(badgeNo, () => []).add(record);
        }
      }
    }

    for (int i = 1; i < rows.length; i++) {
      final values = <String, dynamic>{'upload_date': formattedDate};
      bool hasData = false;
      String? badgeNo;

      // Build record from row
      for (int j = 0; j < headers.length && j < rows[i].length; j++) {
        final value = rows[i][j]?.value?.toString();
        if (value != null) {
          final columnName = _escapeColumnName(headers[j]).replaceAll('"', '');
          values[columnName] = value;
          hasData = true;

          // Store Badge NO for comparison
          if (j == badgeNoIndex) {
            badgeNo = value;
          }
        }
      }

      if (hasData) {
        bool shouldInsert = true;

        // Check if this record is a duplicate based on Badge NO and other fields
        if (badgeNo != null &&
            badgeNoColumnSanitized != null &&
            existingByBadgeNo.containsKey(badgeNo)) {
          final recordsWithSameBadgeNo = existingByBadgeNo[badgeNo]!;

          for (final existingRecord in recordsWithSameBadgeNo) {
            bool isDuplicate = true;

            // Compare only the columns that exist in the new record
            for (final key in values.keys) {
              if (key == 'upload_date' || key == 'id') continue;

              if (values[key]?.toString() != existingRecord[key]?.toString()) {
                isDuplicate = false;
                break;
              }
            }

            if (isDuplicate) {
              shouldInsert = false;
              break;
            }
          }
        }

        if (shouldInsert) {
          batch.insert(tableName, values);
          insertedCount++;
        }
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
        // Skip upload_date and id in comparison
        if (key == 'upload_date' || key == 'id') continue;

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

  String _escapeColumnName(String name) {
    // Replace spaces, periods, parentheses, and other problematic characters
    String sanitized = name
        .replaceAll(' ', '_')
        .replaceAll('.', '')
        .replaceAll('(', '_')
        .replaceAll(')', '_')
        .replaceAll('-', '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('+', '_')
        .replaceAll('&', '_')
        .replaceAll('%', '_');

    // Ensure the column name is valid SQL identifier
    return '"$sanitized"';
  }
}
