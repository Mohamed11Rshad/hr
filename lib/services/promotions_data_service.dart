import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'promotion_calculation_service.dart';

class PromotionsDataService {
  final Database db;
  final String baseTableName;
  late final PromotionCalculationService _calculationService;

  PromotionsDataService({required this.db, required this.baseTableName}) {
    _calculationService = PromotionCalculationService(db);
  }

  Future<void> initializePromotionsTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS promotions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          Badge_NO TEXT NOT NULL UNIQUE,
          Adjusted_Eligible_Date TEXT,
          Prom_Reason TEXT,
          created_date TEXT
        )
      ''');

      // Check if Prom_Reason column exists, if not add it
      try {
        await db.execute('''
          ALTER TABLE promotions ADD COLUMN Prom_Reason TEXT
        ''');
      } catch (e) {
        // Column might already exist, ignore error
        print('Prom_Reason column might already exist: $e');
      }

      // Initialize promoted employees table
      await _initializePromotedTable();
    } catch (e) {
      print('Error creating promotions table: $e');
      rethrow;
    }
  }

  Future<void> _initializePromotedTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS promoted_employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          Badge_NO TEXT NOT NULL,
          Employee_Name TEXT,
          Grade TEXT,
          Status TEXT,
          Adjusted_Eligible_Date TEXT,
          Last_Promotion_Dt TEXT,
          Prom_Reason TEXT,
          promoted_date TEXT NOT NULL,
          created_date TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Check if columns exist, if not add them
      try {
        await db.execute('''
          ALTER TABLE promoted_employees ADD COLUMN Prom_Reason TEXT
        ''');
      } catch (e) {
        print(
          'Prom_Reason column might already exist in promoted_employees: $e',
        );
      }

      try {
        await db.execute('''
          ALTER TABLE promoted_employees ADD COLUMN Status TEXT
        ''');
      } catch (e) {
        print('Status column might already exist in promoted_employees: $e');
      }
    } catch (e) {
      print('Error creating promoted_employees table: $e');
      rethrow;
    }
  }

  Future<void> promoteEmployee(String badgeNo) async {
    try {
      // Get employee data from base table and promotions table
      final baseData = await _getEmployeeFromBaseTable(badgeNo);
      if (baseData == null) {
        throw Exception('Employee not found in base table');
      }

      // Get custom adjusted date and promotion reason from promotions table
      final promotionData = await db.query(
        'promotions',
        where: 'Badge_NO = ?',
        whereArgs: [badgeNo],
        limit: 1,
      );

      final adjustedDate =
          promotionData.isNotEmpty
              ? promotionData.first['Adjusted_Eligible_Date']?.toString() ?? ''
              : baseData['Adjusted_Eligible_Date']?.toString() ?? '';

      final promReason =
          promotionData.isNotEmpty
              ? promotionData.first['Prom_Reason']?.toString() ?? ''
              : _getPromReasonFromBaseData(baseData);

      // Get status from status table - this is crucial for the Status column
      final statusData = await _getStatusData([badgeNo]);
      final status = statusData[badgeNo] ?? 'N/A';

      print('Promoting employee $badgeNo with status: $status'); // Debug print

      final now = DateTime.now().toIso8601String();

      // Insert into promoted_employees table with proper status
      await db.insert('promoted_employees', {
        'Badge_NO': badgeNo,
        'Employee_Name': baseData['Employee_Name']?.toString() ?? '',
        'Grade': baseData['Grade']?.toString() ?? '',
        'Status': status, // Make sure status is properly set
        'Adjusted_Eligible_Date': adjustedDate,
        'Last_Promotion_Dt': baseData['Last_Promotion_Dt']?.toString() ?? '',
        'Prom_Reason': promReason,
        'promoted_date': now,
        'created_date': now,
      });

      // Remove from promotions table
      await db.delete(
        'promotions',
        where: 'Badge_NO = ?',
        whereArgs: [badgeNo],
      );
    } catch (e) {
      print('Error promoting employee: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPromotedEmployees({
    required int limit,
    required int offset,
  }) async {
    try {
      final data = await db.query(
        'promoted_employees',
        orderBy: 'promoted_date DESC',
        limit: limit,
        offset: offset,
      );

      // Convert to mutable maps to avoid read-only issues
      return data.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      print('Error getting promoted employees: $e');
      rethrow;
    }
  }

  Future<void> removePromotedEmployee(
    String badgeNo,
    String promotedDate,
  ) async {
    try {
      await db.delete(
        'promoted_employees',
        where: 'Badge_NO = ? AND promoted_date = ?',
        whereArgs: [badgeNo, promotedDate],
      );
    } catch (e) {
      print('Error removing promoted employee: $e');
      rethrow;
    }
  }

  Future<void> updateAdjustedEligibleDate(
    String badgeNo,
    String newDate,
  ) async {
    try {
      await db.update(
        'promotions',
        {'Adjusted_Eligible_Date': newDate},
        where: 'Badge_NO = ?',
        whereArgs: [badgeNo],
      );
    } catch (e) {
      print('Error updating adjusted eligible date: $e');
      rethrow;
    }
  }

  Future<void> updatePromReason(String badgeNo, String newPromReason) async {
    try {
      await db.update(
        'promotions',
        {'Prom_Reason': newPromReason},
        where: 'Badge_NO = ?',
        whereArgs: [badgeNo],
      );
    } catch (e) {
      print('Error updating prom reason: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPromotionsData({
    required int limit,
    required int offset,
    required List<String> columns,
  }) async {
    try {
      // Get Badge NOs and their custom data from promotions table
      final promotionsBadges = await db.query(
        'promotions',
        columns: ['Badge_NO', 'Adjusted_Eligible_Date', 'Prom_Reason'],
        limit: limit,
        offset: offset,
      );

      if (promotionsBadges.isEmpty) {
        print('No promotions found in database');
        return [];
      }

      final badgeNumbers =
          promotionsBadges
              .map((row) => row['Badge_NO'].toString())
              .where((badge) => badge.isNotEmpty)
              .toList();

      if (badgeNumbers.isEmpty) {
        print('No valid badge numbers found');
        return [];
      }

      print('Found ${badgeNumbers.length} badge numbers: $badgeNumbers');

      // Find badge column in base table
      final badgeColumn = columns.firstWhere(
        (col) => col.toLowerCase().contains('badge'),
        orElse: () => 'Badge_NO',
      );

      print('Using badge column: $badgeColumn');

      // Check if base table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [baseTableName],
      );

      if (tableExists.isEmpty) {
        print('Base table $baseTableName does not exist');
        return [];
      }

      // Get data from base table - only latest record for each badge number
      final placeholders = badgeNumbers.map((_) => '?').join(',');
      final data = await db.rawQuery('''
        SELECT t1.* FROM "$baseTableName" t1
        INNER JOIN (
          SELECT "$badgeColumn", MAX(id) as max_id
          FROM "$baseTableName"
          WHERE "$badgeColumn" IN ($placeholders)
          GROUP BY "$badgeColumn"
        ) t2 ON t1."$badgeColumn" = t2."$badgeColumn" AND t1.id = t2.max_id
        ORDER BY t1.id
      ''', badgeNumbers);

      print(
        'Retrieved ${data.length} records from base table (latest records only)',
      );

      // Get status data for all badge numbers
      final statusData = await _getStatusData(badgeNumbers);

      // Create maps for quick lookup of custom data - ensure they're mutable
      final customDatesMap = <String, String>{};
      final customPromReasonMap = <String, String>{};
      for (final promotion in promotionsBadges) {
        final mutablePromotion = Map<String, dynamic>.from(promotion);
        final badgeNo = mutablePromotion['Badge_NO']?.toString() ?? '';
        final customDate =
            mutablePromotion['Adjusted_Eligible_Date']?.toString() ?? '';
        final customPromReason =
            mutablePromotion['Prom_Reason']?.toString() ?? '';
        if (badgeNo.isNotEmpty) {
          if (customDate.isNotEmpty) {
            customDatesMap[badgeNo] = customDate;
          }
          customPromReasonMap[badgeNo] = customPromReason;
        }
      }

      // Process data with calculations using the PromotionCalculationService
      final processedData = <Map<String, dynamic>>[];
      for (final record in data) {
        try {
          print('Processing record for badge: ${record[badgeColumn]}');

          // Create a mutable copy of the record to avoid read-only issues
          final modifiedRecord = Map<String, dynamic>.from(record);
          final badgeNo = record[badgeColumn]?.toString() ?? '';

          if (customDatesMap.containsKey(badgeNo)) {
            modifiedRecord['Adjusted_Eligible_Date'] = customDatesMap[badgeNo];
          }

          // Add Prom_Reason from promotions table or base table
          if (customPromReasonMap.containsKey(badgeNo)) {
            modifiedRecord['Prom_Reason'] = customPromReasonMap[badgeNo]!;
          } else {
            // Try to get from base table if not in promotions table
            modifiedRecord['Prom_Reason'] = _getPromReasonFromBaseData(record);
          }

          // Add status from status table
          if (statusData.containsKey(badgeNo)) {
            modifiedRecord['Status'] = statusData[badgeNo];
          } else {
            modifiedRecord['Status'] = 'N/A';
          }

          final calculatedRecord = await _calculationService
              .calculatePromotionData(modifiedRecord);
          print(
            'Calculated annual increment: ${calculatedRecord['Annual_Increment']}',
          );
          processedData.add(calculatedRecord);
        } catch (e) {
          print('Error processing record: $e');
          // Add the record without calculations if calculation fails
          final fallbackRecord = Map<String, dynamic>.from(record);
          final badgeNo = record[badgeColumn]?.toString() ?? '';
          if (statusData.containsKey(badgeNo)) {
            fallbackRecord['Status'] = statusData[badgeNo];
          } else {
            fallbackRecord['Status'] = 'N/A';
          }

          // Add Prom_Reason
          if (customPromReasonMap.containsKey(badgeNo)) {
            fallbackRecord['Prom_Reason'] = customPromReasonMap[badgeNo]!;
          } else {
            fallbackRecord['Prom_Reason'] = _getPromReasonFromBaseData(record);
          }

          fallbackRecord['Next_Grade'] = '';
          fallbackRecord['4% Adj'] = '0';
          fallbackRecord['Annual_Increment'] = '0';
          fallbackRecord['New_Basic'] = _formatAsInteger(
            record['Basic']?.toString() ?? '0',
          );
          processedData.add(fallbackRecord);
        }
      }

      return processedData;
    } catch (e) {
      print('Error in getPromotionsData: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _getStatusData(List<String> badgeNumbers) async {
    final statusMap = <String, String>{};

    try {
      // Check if Status table exists
      final statusTableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'Status'",
      );

      if (statusTableExists.isEmpty) {
        print('Status table does not exist');
        return statusMap;
      }

      // Get status data for all badge numbers
      final placeholders = badgeNumbers.map((_) => '?').join(',');
      final statusData = await db.rawQuery('''
        SELECT "Badge_NO", "Status" FROM "Status"
        WHERE "Badge_NO" IN ($placeholders)
      ''', badgeNumbers);

      print(
        'Status query returned ${statusData.length} records',
      ); // Debug print

      for (final row in statusData) {
        final badgeNo = row['Badge_NO']?.toString() ?? '';
        final status = row['Status']?.toString() ?? 'N/A';
        if (badgeNo.isNotEmpty) {
          statusMap[badgeNo] = status;
          print('Found status for $badgeNo: $status'); // Debug print
        }
      }

      print('Retrieved status data for ${statusMap.length} employees');
    } catch (e) {
      print('Error getting status data: $e');
    }

    return statusMap;
  }

  Future<Map<String, dynamic>?> _getEmployeeFromBaseTable(
    String badgeNo,
  ) async {
    try {
      // Get all available columns to find the badge column
      final allColumns = await getAvailableColumns();
      final badgeColumn = allColumns.firstWhere(
        (col) => col.toLowerCase().contains('badge'),
        orElse: () => 'Badge_NO',
      );

      // Query the base table for this specific employee (latest record only)
      final result = await db.rawQuery(
        '''
        SELECT t1.* FROM "$baseTableName" t1
        INNER JOIN (
          SELECT "$badgeColumn", MAX(id) as max_id
          FROM "$baseTableName"
          WHERE "$badgeColumn" = ?
          GROUP BY "$badgeColumn"
        ) t2 ON t1."$badgeColumn" = t2."$badgeColumn" AND t1.id = t2.max_id
        LIMIT 1
      ''',
        [badgeNo],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting employee from base table: $e');
      return null;
    }
  }

  Future<List<String>> getAvailableColumns() async {
    try {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info("$baseTableName")',
      );
      final baseColumns =
          tableInfo.map((col) => col['name'].toString()).toList();
      print('Available columns in $baseTableName: $baseColumns');

      // Add the calculated columns to the available columns
      final allColumns = List<String>.from(baseColumns);

      // Add Status column (it's added dynamically from Status table)
      if (!allColumns.contains('Status')) {
        allColumns.add('Status');
      }

      // Add Prom_Reason column if it doesn't exist
      if (!allColumns.contains('Prom_Reason')) {
        allColumns.add('Prom_Reason');
      }

      // Add calculated columns if they don't already exist
      final calculatedColumns = [
        'Next_Grade',
        '4% Adj',
        'Annual_Increment',
        'New_Basic',
      ];
      for (final calcCol in calculatedColumns) {
        if (!allColumns.contains(calcCol)) {
          allColumns.add(calcCol);
        }
      }

      print('All available columns (including calculated): $allColumns');
      return allColumns;
    } catch (e) {
      print('Error getting available columns: $e');
      rethrow;
    }
  }

  Future<List<String>> checkEmployeesInBaseSheet(
    List<String> badgeNumbers,
  ) async {
    try {
      if (badgeNumbers.isEmpty) return [];

      // Get all available columns to find the badge column
      final allColumns = await getAvailableColumns();
      final badgeColumn = allColumns.firstWhere(
        (col) => col.toLowerCase().contains('badge'),
        orElse: () => 'Badge_NO',
      );

      // Check if base table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [baseTableName],
      );

      if (tableExists.isEmpty) {
        print('Base table $baseTableName does not exist');
        return [];
      }

      // Query the base table to find which badge numbers exist (latest records only)
      final placeholders = badgeNumbers.map((_) => '?').join(',');
      final result = await db.rawQuery('''
        SELECT DISTINCT t1."$badgeColumn" FROM "$baseTableName" t1
        INNER JOIN (
          SELECT "$badgeColumn", MAX(id) as max_id
          FROM "$baseTableName"
          WHERE "$badgeColumn" IN ($placeholders)
          GROUP BY "$badgeColumn"
        ) t2 ON t1."$badgeColumn" = t2."$badgeColumn" AND t1.id = t2.max_id
      ''', badgeNumbers);

      final foundBadges =
          result
              .map((row) => row[badgeColumn]?.toString() ?? '')
              .where((badge) => badge.isNotEmpty)
              .toList();

      print(
        'Found ${foundBadges.length} employees out of ${badgeNumbers.length} requested (latest records only)',
      );
      return foundBadges;
    } catch (e) {
      print('Error checking employees in base sheet: $e');
      rethrow;
    }
  }

  Future<void> removeEmployeeFromPromotions(String badgeNo) async {
    try {
      await db.delete(
        'promotions',
        where: 'Badge_NO = ?',
        whereArgs: [badgeNo],
      );
    } catch (e) {
      print('Error removing employee from promotions: $e');
      rethrow;
    }
  }

  String _getPromReasonFromBaseData(Map<String, dynamic>? baseData) {
    if (baseData == null) return '';

    // Try different possible column names for Prom Reason
    final possibleNames = [
      'Prom_Reason',
      'Prom.Reason',
      'Prom Reason',
      'prom_reason',
      'prom.reason',
      'prom reason',
    ];

    for (final name in possibleNames) {
      if (baseData.containsKey(name)) {
        return baseData[name]?.toString() ?? '';
      }
    }

    return '';
  }

  String _formatAsInteger(String value) {
    final doubleValue = double.tryParse(value) ?? 0;
    return doubleValue.round().toString();
  }

  Future<List<String>> addEmployeesToPromotions(
    List<String> badgeNumbers,
  ) async {
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    final duplicates = <String>[];
    final validationErrors = <String>[];

    try {
      // First, check which employees exist in the base table
      final existingEmployees = await checkEmployeesInBaseSheet(badgeNumbers);

      for (final badgeNo in existingEmployees) {
        final existing = await db.query(
          'promotions',
          where: 'Badge_NO = ?',
          whereArgs: [badgeNo],
        );

        if (existing.isEmpty) {
          // Get the original data from base table
          final baseData = await _getEmployeeFromBaseTable(badgeNo);

          // Validate the employee data before adding
          final validationResult = await _validateEmployeeData(
            baseData,
            badgeNo,
          );
          if (validationResult != null) {
            validationErrors.add(validationResult);
            continue; // Skip this employee
          }

          final originalDate =
              baseData?['Adjusted_Eligible_Date']?.toString() ?? '';
          final originalPromReason = _getPromReasonFromBaseData(baseData);

          batch.insert('promotions', {
            'Badge_NO': badgeNo,
            'Adjusted_Eligible_Date': originalDate,
            'Prom_Reason': originalPromReason,
            'created_date': now,
          });
        } else {
          duplicates.add(badgeNo);
        }
      }

      await batch.commit();

      // Return both duplicates and validation errors
      final allErrors = <String>[];
      allErrors.addAll(duplicates);
      allErrors.addAll(validationErrors);
      return allErrors;
    } catch (e) {
      print('Error adding employees to promotions: $e');
      rethrow;
    }
  }

  Future<String?> _validateEmployeeData(
    Map<String, dynamic>? baseData,
    String badgeNo,
  ) async {
    if (baseData == null) return null;

    try {
      // Validate Old Basic against Salary Scale
      final basicValidation = await _validateOldBasic(baseData, badgeNo);
      if (basicValidation != null) return basicValidation;

      // Validate Grade and Next Grade against Grade Range
      final gradeValidation = await _validateGradeRange(baseData, badgeNo);
      if (gradeValidation != null) return gradeValidation;

      return null; // All validations passed
    } catch (e) {
      print('Error validating employee data for $badgeNo: $e');
      return null; // Allow addition if validation fails
    }
  }

  Future<String?> _validateOldBasic(
    Map<String, dynamic> baseData,
    String badgeNo,
  ) async {
    try {
      final oldBasic =
          double.tryParse(baseData['Basic']?.toString() ?? '0') ?? 0;
      final grade = baseData['Grade']?.toString() ?? '';
      final payScaleArea = baseData['pay_scale_area_text']?.toString() ?? '';

      if (oldBasic == 0 || grade.isEmpty) return null;

      // Determine which salary scale table to use
      final salaryScaleTable =
          payScaleArea.contains('Category B')
              ? 'Salary_Scale_B'
              : 'Salary_Scale_A';

      // Get minimum and maximum salary for this grade
      final salaryScaleData = await db.query(
        salaryScaleTable,
        where: 'Grade = ?',
        whereArgs: [grade],
      );

      if (salaryScaleData.isNotEmpty) {
        final minimum =
            double.tryParse(
              salaryScaleData.first['minimum']?.toString() ?? '0',
            ) ??
            0;
        final maximum =
            double.tryParse(
              salaryScaleData.first['maximum']?.toString() ?? '0',
            ) ??
            0;

        // Check if old basic is below minimum
        if (oldBasic < minimum) {
          return 'Badge $badgeNo: Old Basic (${oldBasic.round()}) is below minimum (${minimum.round()}) for Grade $grade';
        }

        // Check if old basic exceeds maximum
        if (oldBasic > maximum) {
          return 'Badge $badgeNo: Old Basic (${oldBasic.round()}) exceeds maximum (${maximum.round()}) for Grade $grade';
        }
      }

      return null;
    } catch (e) {
      print('Error validating old basic for $badgeNo: $e');
      return null;
    }
  }

  Future<String?> _validateGradeRange(
    Map<String, dynamic> baseData,
    String badgeNo,
  ) async {
    try {
      final currentGrade = baseData['Grade']?.toString() ?? '';
      final gradeRange = baseData['Grade_Range']?.toString() ?? '';

      if (currentGrade.isEmpty || gradeRange.isEmpty) return null;

      // Calculate next grade
      final currentGradeInt =
          int.tryParse(currentGrade.replaceAll(RegExp(r'^0+'), '')) ?? 0;
      final nextGradeInt = currentGradeInt + 1;

      if (currentGradeInt == 0) return null;

      // Parse grade range (format: 008-013)
      final rangeParts = gradeRange.split('-');
      if (rangeParts.length < 2) return null;

      final rangeMin =
          int.tryParse(rangeParts[0].replaceAll(RegExp(r'^0+'), '')) ?? 0;
      final rangeMax =
          int.tryParse(rangeParts[1].replaceAll(RegExp(r'^0+'), '')) ?? 0;

      if (rangeMin == 0 || rangeMax == 0) return null;

      // Check if current grade is within range
      if (currentGradeInt < rangeMin || currentGradeInt > rangeMax) {
        return 'Badge $badgeNo: Current Grade ($currentGradeInt) is not within Grade Range ($gradeRange)';
      }

      // Check if next grade is within range
      if (nextGradeInt > rangeMax) {
        return 'Badge $badgeNo: Next Grade ($nextGradeInt) would exceed Grade Range maximum ($rangeMax)';
      }

      return null;
    } catch (e) {
      print('Error validating grade range for $badgeNo: $e');
      return null;
    }
  }
}
