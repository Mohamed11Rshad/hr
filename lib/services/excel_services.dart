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

      // Insert data and get counts
      final counts = await _insertDataWithCounts(tableName, rows, headers);
      final insertedCount = counts['inserted'] ?? 0;
      final updatedCount = counts['updated'] ?? 0;

      if (insertedCount > 0 && updatedCount > 0) {
        result =
            'تمت معالجة جدول "$tableName" - المضاف: $insertedCount، المحدث: $updatedCount';
      } else if (insertedCount > 0) {
        result = 'تمت الإضافة لجدول "$tableName" المضاف: $insertedCount';
      } else if (updatedCount > 0) {
        result = 'تم تحديث جدول "$tableName" المحدث: $updatedCount';
      } else {
        result = 'لا توجد تغييرات في جدول "$tableName"';
      }
      break; // Only process first sheet
    }
    return result;
  }

  Future<Map<String, int>> _insertDataWithCounts(
    String tableName,
    List<List<Data?>> rows,
    List<String> headers,
  ) async {
    int insertedCount = 0;
    int updatedCount = 0;
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

    // Process data in chunks to prevent UI blocking
    const int chunkSize = 500;

    for (
      int startIndex = 1;
      startIndex < rows.length;
      startIndex += chunkSize
    ) {
      final endIndex = (startIndex + chunkSize).clamp(0, rows.length);
      final batch = db.batch();

      for (int i = startIndex; i < endIndex; i++) {
        final values = <String, dynamic>{'upload_date': formattedDate};
        bool hasData = false;
        String? badgeNo;

        // Build record from row
        for (int j = 0; j < headers.length && j < rows[i].length; j++) {
          final value = rows[i][j]?.value?.toString();
          if (value != null) {
            final columnName = _escapeColumnName(
              headers[j],
            ).replaceAll('"', '');
            values[columnName] = value;
            hasData = true;

            if (j == badgeNoIndex) {
              badgeNo = value;
            }
          }
        }

        if (hasData) {
          bool shouldInsert = true;
          int? existingRecordId;

          if (badgeNo != null &&
              badgeNoColumnSanitized != null &&
              existingByBadgeNo.containsKey(badgeNo)) {
            final recordsWithSameBadgeNo = existingByBadgeNo[badgeNo]!;

            for (final existingRecord in recordsWithSameBadgeNo) {
              bool isDuplicate = true;

              for (final key in values.keys) {
                if (key == 'upload_date' || key == 'id') continue;

                if (values[key]?.toString() !=
                    existingRecord[key]?.toString()) {
                  isDuplicate = false;
                  break;
                }
              }

              if (isDuplicate) {
                shouldInsert = false;
                existingRecordId = existingRecord['id'] as int?;
                break;
              }
            }
          }

          if (shouldInsert) {
            batch.insert(tableName, values);
            insertedCount++;
          } else if (existingRecordId != null) {
            batch.update(
              tableName,
              {'upload_date': formattedDate},
              where: 'id = ?',
              whereArgs: [existingRecordId],
            );
            updatedCount++;
          }
        }
      }

      await batch.commit(noResult: true);

      if (endIndex < rows.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    return {'inserted': insertedCount, 'updated': updatedCount};
  }

  // New method to create table only if it doesn't exist
  Future<void> _createTableIfNotExists(
    String tableName,
    List<String> headers,
  ) async {
    print(
      'Creating/updating table "$tableName" with ${headers.length} headers',
    );
    print('Headers: $headers');

    // Check if table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [tableName],
    );

    if (tables.isEmpty) {
      // Table doesn't exist, create it
      print('Creating new table "$tableName"');
      final columns = headers
          .map((h) => '${_escapeColumnName(h)} TEXT')
          .join(', ');

      final createTableSQL = '''
        CREATE TABLE "$tableName" (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          $columns,
          upload_date TEXT
        )
      ''';

      print('Create table SQL: $createTableSQL');

      await db.execute(createTableSQL);
      print('Table "$tableName" created successfully');
    } else {
      // Table exists, check if we need to add new columns
      print('Table "$tableName" exists, checking for missing columns');
      final existingColumns = await db.rawQuery(
        'PRAGMA table_info("$tableName")',
      );
      final existingColumnNames =
          existingColumns.map((col) => col['name'].toString()).toList();

      print('Existing columns in table: $existingColumnNames');

      // Add any missing columns
      for (final header in headers) {
        final escapedName = _escapeColumnName(header);
        final sanitizedName = escapedName.replaceAll('"', '');

        print(
          'Checking header "$header" -> escaped: "$escapedName" -> sanitized: "$sanitizedName"',
        );

        // Check if column already exists (case-insensitive comparison)
        final columnExists = existingColumnNames.any(
          (existing) => existing.toLowerCase() == sanitizedName.toLowerCase(),
        );

        print('Column exists (case-insensitive): $columnExists');

        if (!columnExists) {
          try {
            print('Adding new column $escapedName to table "$tableName"');
            await db.execute(
              'ALTER TABLE "$tableName" ADD COLUMN $escapedName TEXT',
            );
            print('Column $escapedName added successfully');
          } catch (e) {
            print('Error adding column $escapedName: $e');
            rethrow; // Re-throw to see the actual error
          }
        } else {
          print('Column "$sanitizedName" already exists, skipping');
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
    int insertedCount = 0;
    int updatedCount = 0;
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

    // Process data in chunks to prevent UI blocking
    const int chunkSize = 500; // Process 500 rows at a time
    final totalRows = rows.length - 1; // Exclude header row

    for (
      int startIndex = 1;
      startIndex < rows.length;
      startIndex += chunkSize
    ) {
      final endIndex = (startIndex + chunkSize).clamp(0, rows.length);
      final batch = db.batch();

      for (int i = startIndex; i < endIndex; i++) {
        final values = <String, dynamic>{'upload_date': formattedDate};
        bool hasData = false;
        String? badgeNo;

        // Build record from row
        for (int j = 0; j < headers.length && j < rows[i].length; j++) {
          final value = rows[i][j]?.value?.toString();
          if (value != null) {
            final columnName = _escapeColumnName(
              headers[j],
            ).replaceAll('"', '');
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
          int? existingRecordId;

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

                if (values[key]?.toString() !=
                    existingRecord[key]?.toString()) {
                  isDuplicate = false;
                  break;
                }
              }

              if (isDuplicate) {
                shouldInsert = false;
                existingRecordId = existingRecord['id'] as int?;
                break;
              }
            }
          }

          if (shouldInsert) {
            batch.insert(tableName, values);
            insertedCount++;
          } else if (existingRecordId != null) {
            // Update the upload_date for the existing record
            batch.update(
              tableName,
              {'upload_date': formattedDate},
              where: 'id = ?',
              whereArgs: [existingRecordId],
            );
            updatedCount++;
          }
        }
      }

      // Commit this batch
      await batch.commit(noResult: true);

      // Add a small delay between chunks to allow UI updates
      if (endIndex < rows.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    return insertedCount; // You could return both insertedCount and updatedCount if needed
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
    final headers = <String>[];
    final seenHeaders = <String>{};

    print('Processing ${headerRow.length} headers from Excel file...');

    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      final header = cell?.value.toString().trim() ?? '';

      if (header.isEmpty) {
        print('Skipping empty header at position $i');
        continue;
      }

      print('Processing header at position $i: "$header"');

      // Handle duplicate headers by adding a suffix
      String uniqueHeader = header;
      int counter = 1;
      while (seenHeaders.contains(uniqueHeader)) {
        print(
          'Found duplicate header "$header", creating unique name: "${header}_$counter"',
        );
        uniqueHeader = '${header}_$counter';
        counter++;
      }

      if (uniqueHeader != header) {
        print('Header "$header" renamed to "$uniqueHeader" to avoid duplicate');
      }

      headers.add(uniqueHeader);
      seenHeaders.add(uniqueHeader);
    }

    print('Final processed headers (${headers.length}): $headers');
    return headers;
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

  Future<String?> validateBadgeUniqueness(
    List<List<Data?>> rows,
    List<String> headers,
  ) async {
    // Find badge and name columns
    final badgeColumnIndex = _findBadgeColumnIndex(headers);
    final nameColumnIndex = _findNameColumnIndex(headers);

    if (badgeColumnIndex == -1) {
      return 'خطأ: لم يتم العثور على عمود Badge أو Badge_NO في الملف';
    }

    if (nameColumnIndex == -1) {
      return 'خطأ: لم يتم العثور على عمود Employee_Name في الملف';
    }

    final badgeToNameMap = <String, String>{};
    final duplicateBadges = <String>{};

    // Check within the file for badge duplicates with different names
    for (int i = 1; i < rows.length; i++) {
      // Skip header row
      final row = rows[i];

      if (badgeColumnIndex >= row.length || nameColumnIndex >= row.length)
        continue;

      final badgeCell = row[badgeColumnIndex];
      final nameCell = row[nameColumnIndex];

      if (badgeCell == null || nameCell == null) continue;

      final badgeNo = badgeCell.value.toString().trim();
      final employeeName = nameCell.value.toString().trim();

      if (badgeNo.isEmpty || employeeName.isEmpty) continue;

      if (badgeToNameMap.containsKey(badgeNo)) {
        // Badge already exists, check if name is different
        if (badgeToNameMap[badgeNo] != employeeName) {
          duplicateBadges.add(badgeNo);
        }
      } else {
        badgeToNameMap[badgeNo] = employeeName;
      }
    }

    // Check against existing database records
    final dbDuplicates = await _checkBadgeAgainstDatabase(badgeToNameMap);
    duplicateBadges.addAll(dbDuplicates);

    if (duplicateBadges.isNotEmpty) {
      return 'خطأ: أرقام الموظفين التالية مكررة : ${duplicateBadges.join(', ')}';
    }

    return null; // No duplicates found
  }

  int _findBadgeColumnIndex(List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      if (header.contains('badge') &&
          (header.contains('no') || header.contains('_no'))) {
        return i;
      }
    }
    return -1;
  }

  int _findNameColumnIndex(List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase();
      if (header.contains('employee') && header.contains('name')) {
        return i;
      }
    }
    return -1;
  }

  Future<Set<String>> _checkBadgeAgainstDatabase(
    Map<String, String> badgeToNameMap,
  ) async {
    final duplicates = <String>{};

    try {
      // Check if Base_Sheet table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'Base_Sheet'",
      );

      if (tableExists.isEmpty) {
        return duplicates; // No existing data to check against
      }

      // Get existing badge-name pairs from database
      final existingRecords = await db.rawQuery('''
        SELECT DISTINCT Badge_NO, Employee_Name 
        FROM Base_Sheet 
        WHERE Badge_NO IS NOT NULL AND Employee_Name IS NOT NULL
      ''');

      final dbBadgeToNameMap = <String, String>{};
      for (final record in existingRecords) {
        final badgeNo = record['Badge_NO']?.toString().trim() ?? '';
        final employeeName = record['Employee_Name']?.toString().trim() ?? '';

        if (badgeNo.isNotEmpty && employeeName.isNotEmpty) {
          dbBadgeToNameMap[badgeNo] = employeeName;
        }
      }

      // Check for conflicts between file data and database data
      for (final entry in badgeToNameMap.entries) {
        final badgeNo = entry.key;
        final fileName = entry.value;

        if (dbBadgeToNameMap.containsKey(badgeNo)) {
          final dbName = dbBadgeToNameMap[badgeNo]!;
          if (dbName != fileName) {
            duplicates.add(badgeNo);
          }
        }
      }
    } catch (e) {
      print('Error checking badge against database: $e');
      // Don't fail the entire process for database check errors
    }

    return duplicates;
  }

  // Add validation call before table creation
  Future<String> processExcelFileWithValidation(File file) async {
    try {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Find the first sheet with data
      String? targetSheetName;
      for (var sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;
        if (sheet.rows.isNotEmpty) {
          targetSheetName = sheetName;
          break;
        }
      }

      if (targetSheetName == null) {
        return 'لا توجد بيانات في الملف';
      }

      final sheet = excel.tables[targetSheetName]!;
      final rows = sheet.rows;

      if (rows.isEmpty) {
        return 'الملف فارغ';
      }

      // Get headers from first row
      final headerRow = rows[0];
      final headers = <String>[];

      for (var cell in headerRow) {
        final header = cell?.value.toString().trim() ?? '';
        if (header.isNotEmpty) {
          headers.add(header);
        }
      }

      if (headers.isEmpty) {
        return 'لا توجد أعمدة في الملف';
      }

      // Check for duplicate headers
      final headerSet = <String>{};
      final duplicateHeaders = <String>{};

      for (final header in headers) {
        if (headerSet.contains(header)) {
          duplicateHeaders.add(header);
        } else {
          headerSet.add(header);
        }
      }

      if (duplicateHeaders.isNotEmpty) {
        return 'خطأ: الأعمدة ${duplicateHeaders.join(', ')} مكررة';
      }

      // Validate badge number uniqueness BEFORE processing
      final badgeValidation = await validateBadgeUniqueness(rows, headers);
      if (badgeValidation != null) {
        return badgeValidation;
      }

      // Continue with normal processing - call original method
      return await processExcelFile(file);
    } catch (e) {
      return 'خطأ في معالجة الملف: ${e.toString()}';
    }
  }
}
