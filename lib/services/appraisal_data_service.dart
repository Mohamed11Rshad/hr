import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/category_mapper.dart';

class AppraisalDataService {
  final Database db;
  final String baseTableName;

  AppraisalDataService({required this.db, required this.baseTableName}) {
    _initializeTables();
  }

  Future<void> _initializeTables() async {
    try {
      // Create appraisal table for storing grade and new basic system changes
      await db.execute('''
        CREATE TABLE IF NOT EXISTS appraisal (
          badge_no TEXT PRIMARY KEY,
          grade TEXT,
          new_basic_system TEXT,
          changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create Adjustments table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Adjustments (
          Badge_NO TEXT PRIMARY KEY,
          Adjustments TEXT
        )
      ''');

      debugPrint('Successfully initialized appraisal table');
    } catch (e) {
      debugPrint('Error initializing tables: $e');
    }
  }

  Future<Map<String, dynamic>> recalculateForGrade(
    Map<String, dynamic> record,
    String newGrade,
  ) async {
    debugPrint('Recalculating for new grade: $newGrade');
    final updatedRecord = Map<String, dynamic>.from(record);
    updatedRecord['Grade'] = newGrade;

    // Get the base amount from Base_Sheet
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final baseData = await db.query(
      baseTableName,
      where: 'Badge_NO = ?',
      whereArgs: [badgeNo],
      orderBy: 'upload_date DESC',
      limit: 1,
    );

    // Start with base amount from latest data
    var basicAmount =
        baseData.isNotEmpty
            ? double.tryParse(baseData.first['Basic']?.toString() ?? '0') ?? 0.0
            : 0.0;
    debugPrint('Base amount from sheet: $basicAmount');

    // Recalculate MIDPOINT and MAXIMUM for new grade
    final midpoint = await _calculateMidpointForCurrentGrade(updatedRecord);
    final maximum = await _calculateMaximumForCurrentGrade(updatedRecord);
    debugPrint('New grade limits - Midpoint: $midpoint, Maximum: $maximum');

    // Get fresh adjustments from Adjustments table
    final adjustmentsData = await db.query(
      'Adjustments',
      where: 'Badge_NO = ?',
      whereArgs: [badgeNo],
    );

    // Get adjustments value
    var adjustmentsValue =
        adjustmentsData.isNotEmpty
            ? double.tryParse(
                  adjustmentsData.first['Adjustments']?.toString() ?? '0',
                ) ??
                0.0
            : 0.0;
    debugPrint('Available adjustments: $adjustmentsValue');

    // Apply adjustments up to the maximum allowed by new grade
    if (basicAmount < maximum && adjustmentsValue > 0) {
      final roomForAdjustment = maximum - basicAmount;
      debugPrint('Room for adjustment: $roomForAdjustment');

      final adjustmentToApply =
          adjustmentsValue > roomForAdjustment
              ? roomForAdjustment
              : adjustmentsValue;

      debugPrint('Applying adjustment: $adjustmentToApply');
      basicAmount += adjustmentToApply;
      adjustmentsValue -= adjustmentToApply;

      debugPrint(
        'After adjustment - Basic: $basicAmount, Remaining adjustments: $adjustmentsValue',
      );
    } else {
      debugPrint(
        'No adjustments applied - Basic: $basicAmount, Maximum: $maximum, Adjustments: $adjustmentsValue',
      );
    }

    // Calculate all the derived values based on the new amounts
    final annualIncrementValue = await _calculateAnnualIncrementForCurrentGrade(
      updatedRecord,
    );
    final actualIncreaseValue = _calculateActualIncrease(
      basicAmount,
      annualIncrementValue,
      maximum,
      updatedRecord,
    );
    final lumpSumPaymentValue = annualIncrementValue - actualIncreaseValue;
    final totalLumpSum = lumpSumPaymentValue * 12;
    final newBasicValue = actualIncreaseValue + basicAmount;

    // Update the record with all new calculations
    updatedRecord.addAll({
      'MIDPOINT': midpoint.toString(),
      'MAXIMUM': maximum.toString(),
      'Basic': basicAmount.toString(),
      'Adjustments': adjustmentsValue.toString(),
      'Original_Adjustments': adjustmentsValue.toString(),
      'Annual_Increment': annualIncrementValue.toString(),
      'Actual_Increase': actualIncreaseValue.toStringAsFixed(2),
      'Lump_Sum_Payment': lumpSumPaymentValue.toStringAsFixed(2),
      'Total_Lump_Sum_12_Months': totalLumpSum.toStringAsFixed(2),
      'New_Basic': newBasicValue.toStringAsFixed(2),
      'New_Basic_System':
          record['New_Basic_System']?.toString() ?? newBasicValue.toString(),
    });

    // Save the grade change and new basic system value
    await saveGradeChange(
      badgeNo,
      newGrade,
      updatedRecord['New_Basic_System']!,
    );

    debugPrint('Final calculations for Badge_NO $badgeNo:');
    debugPrint('- New Grade: $newGrade');
    debugPrint('- Basic Amount: $basicAmount');
    debugPrint('- Remaining Adjustments: $adjustmentsValue');
    debugPrint('- Maximum: $maximum');
    debugPrint('- Annual Increment: $annualIncrementValue');
    debugPrint('- New Basic: $newBasicValue');

    return updatedRecord;
  }

  Future<List<Map<String, dynamic>>> getAppraisalData() async {
    try {
      debugPrint('Starting to fetch appraisal data from $baseTableName...');
      final List<Map<String, dynamic>> appraisalData = [];

      // Check if table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [baseTableName],
      );

      if (tables.isEmpty) {
        debugPrint('Table $baseTableName does not exist');
        return [];
      }

      // Check if table has data
      final tableCheck = await db.rawQuery(
        'SELECT count(*) as count FROM "$baseTableName"',
      );
      final recordCount = tableCheck.first['count'] as int? ?? 0;
      debugPrint('Found $recordCount total records in $baseTableName');

      if (recordCount == 0) {
        debugPrint('No records found in table');
        return [];
      }

      // Get the latest upload_date from the base table
      final latestDateQuery = await db.rawQuery(
        'SELECT MAX(upload_date) as latest_date FROM "$baseTableName" WHERE upload_date IS NOT NULL',
      );
      debugPrint('Latest date query result: $latestDateQuery');

      final latestDate = latestDateQuery.first['latest_date']?.toString();
      if (latestDate == null || latestDate.isEmpty) {
        debugPrint('No upload date found');
        return [];
      }
      debugPrint('Found latest date: $latestDate');

      // Check how many records have this upload date
      final dateRecordCount = await db.rawQuery(
        'SELECT count(*) as count FROM "$baseTableName" WHERE upload_date = ?',
        [latestDate],
      );
      debugPrint(
        'Found ${dateRecordCount.first['count']} records for latest date',
      );

      // Get all records with the latest upload_date
      debugPrint('Fetching all records with latest date...');
      var latestData = await db.rawQuery(
        'SELECT * FROM "$baseTableName" WHERE upload_date = ? ORDER BY CAST(REPLACE(Badge_NO, \' \', \'\') AS INTEGER)',
        [latestDate],
      );

      // Try to enrich data with grade changes and adjustments
      try {
        final query = '''
          SELECT b.*, 
                 COALESCE(a_table.grade, b.Grade) as Grade,
                 COALESCE(a_table.new_basic_system, '') as New_Basic_System,
                 COALESCE(adj.Adjustments, '0') as original_adjustments 
          FROM "$baseTableName" b
          LEFT JOIN appraisal a_table ON b.Badge_NO = a_table.badge_no
          LEFT JOIN Adjustments adj ON b.Badge_NO = adj.Badge_NO
          WHERE b.upload_date = ?
          ORDER BY CAST(REPLACE(b.Badge_NO, ' ', '') AS INTEGER)
          ''';
        debugPrint('Executing query: $query');
        debugPrint('With parameters: $latestDate');

        final enrichedData = await db.rawQuery(query, [latestDate]);
        if (enrichedData.isNotEmpty) {
          latestData = enrichedData;
          debugPrint(
            'Successfully enriched data with appraisal table and adjustments',
          );
        }
      } catch (e, stackTrace) {
        debugPrint(
          'Warning: Could not enrich data with appraisal table and adjustments:',
        );
        debugPrint('Error: $e');
        debugPrint('Stack trace: $stackTrace');

        // Verify table structure and attempt to fix it
        try {
          debugPrint('Attempting to verify and fix table structure...');

          // Re-run table initialization
          await _initializeTables();

          // Verify structure
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          );
          debugPrint(
            'Available tables: ${tables.map((t) => t['name']).join(', ')}',
          );

          if (tables.any((t) => t['name'] == 'appraisal')) {
            final structure = await db.rawQuery('PRAGMA table_info(appraisal)');
            debugPrint('appraisal table structure: $structure');

            // Try the query again after fixing the structure
            final retryQuery = '''
              SELECT b.*, 
                     COALESCE(a_table.grade, b.Grade) as Grade,
                     COALESCE(a_table.new_basic_system, '') as New_Basic_System,
                     COALESCE(adj.Adjustments, '0') as original_adjustments 
              FROM "$baseTableName" b
              LEFT JOIN appraisal a_table ON b.Badge_NO = a_table.badge_no
              LEFT JOIN Adjustments adj ON b.Badge_NO = adj.Badge_NO
              WHERE b.upload_date = ?
              ORDER BY CAST(REPLACE(b.Badge_NO, ' ', '') AS INTEGER)
            ''';
            final enrichedData = await db.rawQuery(retryQuery, [latestDate]);
            if (enrichedData.isNotEmpty) {
              latestData = enrichedData;
              debugPrint(
                'Successfully recovered and enriched data after fixing table structure',
              );
            }
          }
        } catch (e2) {
          debugPrint('Error fixing table structure: $e2');
        }

        // If we get here, continue with basic data
        debugPrint('Falling back to basic data without enrichment');
      } // Process each record from latest data
      for (final record in latestData) {
        // Extract required fields from base table
        final badgeNo = record['Badge_NO']?.toString() ?? '';
        final employeeName = record['Employee_Name']?.toString() ?? '';
        final busLine = record['Bus_Line']?.toString() ?? '';
        final departText = record['Depart_Text']?.toString() ?? '';
        final grade = record['Grade']?.toString() ?? '';
        final appraisal5 = record['Appraisal5']?.toString() ?? '';
        var basic = record['Basic']?.toString() ?? '';
        var basicAmount = double.tryParse(basic) ?? 0.0;

        // Get Adjustments value from Adjustments table
        final adjustmentsData = await db.query(
          'Adjustments',
          where: 'Badge_NO = ?',
          whereArgs: [badgeNo],
        );

        // Parse adjustments value
        var adjustmentsValue =
            adjustmentsData.isNotEmpty
                ? double.tryParse(
                      adjustmentsData.first['Adjustments']?.toString() ?? '0',
                    ) ??
                    0.0
                : 0.0;

        // Get maximum for current grade
        final maximum = await _calculateMaximumForCurrentGrade(record);

        // If basic amount is less than maximum and we have adjustments
        if (basicAmount < maximum && adjustmentsValue > 0) {
          // Calculate how much we can add from adjustments
          final roomForAdjustment = maximum - basicAmount;
          final adjustmentToApply =
              adjustmentsValue > roomForAdjustment
                  ? roomForAdjustment
                  : adjustmentsValue;

          // Update basic amount and adjustments
          basicAmount += adjustmentToApply;
          adjustmentsValue -= adjustmentToApply;

          // Update the values for display
          basic = basicAmount.toString();
        }

        // Convert remaining adjustments to string for display
        final adjustments = adjustmentsValue.toString();

        // Calculate MIDPOINT and MAXIMUM using current grade (not next grade)
        final midpoint = await _calculateMidpointForCurrentGrade(record);
        final gradeMaximum = await _calculateMaximumForCurrentGrade(record);

        // Calculate Annual Increment using current grade
        final annualIncrement = await _calculateAnnualIncrementForCurrentGrade(
          record,
        );

        // Calculate الزيادة الفعلية (Actual Increase)
        final actualIncrease = _calculateActualIncrease(
          basicAmount,
          annualIncrement,
          gradeMaximum,
          record,
        );

        // Calculate Lump sum payment
        final lumpSumPayment = annualIncrement - actualIncrease;

        // Calculate Total Lump Sum for 12 months
        final totalLumpSum12Months = lumpSumPayment * 12;

        // Calculate New Basic
        final newBasic = actualIncrease + basicAmount;

        appraisalData.add({
          'Badge_NO': record['Badge_NO']?.toString() ?? '',
          'Employee_Name': employeeName,
          'Bus_Line': busLine,
          'Depart_Text': departText,
          'Grade': grade,
          'Appraisal5': appraisal5,
          'Adjustments': adjustments,
          'Basic': basic,
          'MIDPOINT': midpoint.toString(),
          'MAXIMUM': maximum.toString(),
          'Annual_Increment': annualIncrement.toString(),
          'Actual_Increase': actualIncrease.toStringAsFixed(2),
          'Lump_Sum_Payment': lumpSumPayment.toStringAsFixed(2),
          'Total_Lump_Sum_12_Months': totalLumpSum12Months.toStringAsFixed(2),
          'New_Basic': newBasic.toStringAsFixed(2),
          'New_Basic_System':
              record['New_Basic_System']?.toString() ??
              '', // Use saved value if exists
        });
      }

      return appraisalData;
    } catch (e) {
      debugPrint('Error fetching appraisal data: $e');
      return [];
    }
  }

  Future<double> _calculateMidpointForCurrentGrade(
    Map<String, dynamic> baseData,
  ) async {
    try {
      var grade = baseData['Grade']?.toString() ?? '';
      if (grade.isEmpty) return 0.0;

      if (grade.startsWith('0')) {
        grade = grade.substring(1); // Remove leading zero if present
      }

      // Determine salary scale table using CategoryMapper
      final payScaleArea = baseData['Pay_scale_area_text']?.toString() ?? '';
      final salaryScaleTable = CategoryMapper.getSalaryScaleTable(payScaleArea);

      // Get salary scale data for midpoint calculation using current grade
      final salaryScaleData = await db.query(
        salaryScaleTable,
        where: 'Grade = ?',
        whereArgs: [grade],
      );

      if (salaryScaleData.isEmpty) return 0.0;

      final midpoint =
          double.tryParse(
            salaryScaleData.first['midpoint']?.toString() ?? '0',
          ) ??
          0.0;

      return midpoint;
    } catch (e) {
      debugPrint('Error calculating midpoint: $e');
      return 0.0;
    }
  }

  Future<double> _calculateMaximumForCurrentGrade(
    Map<String, dynamic> baseData,
  ) async {
    try {
      var grade = baseData['Grade']?.toString() ?? '';
      if (grade.isEmpty) return 0.0;

      if (grade.startsWith('0')) {
        grade = grade.substring(1); // Remove leading zero if present
      }

      // Determine salary scale table using CategoryMapper
      final payScaleArea = baseData['Pay_scale_area_text']?.toString() ?? '';
      final salaryScaleTable = CategoryMapper.getSalaryScaleTable(payScaleArea);

      // Get salary scale data for maximum calculation using current grade
      final salaryScaleData = await db.query(
        salaryScaleTable,
        where: 'Grade = ?',
        whereArgs: [grade],
      );

      if (salaryScaleData.isEmpty) return 0.0;

      final maximum =
          double.tryParse(
            salaryScaleData.first['maximum']?.toString() ?? '0',
          ) ??
          0.0;

      return maximum;
    } catch (e) {
      debugPrint('Error calculating maximum: $e');
      return 0.0;
    }
  }

  Future<double> _calculateAnnualIncrementForCurrentGrade(
    Map<String, dynamic> baseData,
  ) async {
    try {
      var grade = baseData['Grade']?.toString() ?? '';
      if (grade.isEmpty) return 0.0;

      if (grade.startsWith('0')) {
        grade = grade.substring(1); // Remove leading zero if present
      }

      // Determine salary scale and annual increase tables using CategoryMapper
      final payScaleArea = baseData['Pay_scale_area_text']?.toString() ?? '';
      final annualIncreaseTable = CategoryMapper.getAnnualIncreaseTable(
        payScaleArea,
      );
      final salaryScaleTable = CategoryMapper.getSalaryScaleTable(payScaleArea);

      // Get salary scale data for midpoint calculation using current grade
      final salaryScaleData = await db.query(
        salaryScaleTable,
        where: 'Grade = ?',
        whereArgs: [grade],
      );

      if (salaryScaleData.isEmpty) return 0.0;

      final midpoint =
          double.tryParse(
            salaryScaleData.first['midpoint']?.toString() ?? '0',
          ) ??
          0.0;

      // Determine midpoint status
      final oldBasic =
          double.tryParse(baseData['Basic']?.toString() ?? '0')?.round() ?? 0;
      final fourPercentAdj = oldBasic * 0.04;
      final oldBasePlusAdj = oldBasic + fourPercentAdj;
      final midpointStatus = (oldBasePlusAdj < midpoint) ? 'b' : 'a';

      // Get annual increase data - use a default appraisal if not set
      var appraisalList = baseData['Appraisal5']?.toString().split('-');
      String appraisalValue;
      if (appraisalList != null && appraisalList.length > 1) {
        appraisalValue = appraisalList[1].replaceAll('+', 'p');
      } else {
        appraisalValue = '3';
      }

      // Get annual increase data for current grade
      final annualIncreaseData = await db.query(
        annualIncreaseTable,
        where: 'Grade = ?',
        whereArgs: [grade],
      );

      if (annualIncreaseData.isEmpty) return 0.0;

      final potentialIncrement =
          double.tryParse(
            annualIncreaseData.first['${appraisalValue}_$midpointStatus']
                    ?.toString() ??
                '0',
          ) ??
          0.0;

      return potentialIncrement < 0 ? 0.0 : potentialIncrement;
    } catch (e) {
      debugPrint('Error calculating annual increment: $e');
      return 0.0;
    }
  }

  // Calculate الزيادة الفعلية (Actual Increase)
  double _calculateActualIncrease(
    double amount,
    double annualIncrement,
    double maximum,
    Map<String, dynamic> employeeRecord,
  ) {
    // First calculate the normal actual increase
    double actualIncrease;
    if (amount + annualIncrement > maximum) {
      actualIncrease = maximum - amount;
    } else {
      actualIncrease = annualIncrement;
    }

    // Check if employee joined in the current year and apply pro-rating
    final joinDateStr = employeeRecord['Date_of_Join']?.toString() ?? '';
    if (joinDateStr.isNotEmpty) {
      try {
        final joinDate = _parseJoinDate(joinDateStr);
        final currentYear = DateTime.now().year;

        // If employee joined in the current year, apply pro-rating
        if (joinDate.year == currentYear) {
          final dailyIncrement = annualIncrement / 365;
          final workingDays = _calculateWorkingDaysFromJoinToYearEnd(joinDate);
          final maxAllowedIncrease = dailyIncrement * workingDays;

          // Cap the actual increase to the pro-rated amount
          if (actualIncrease > maxAllowedIncrease) {
            actualIncrease = maxAllowedIncrease;
          }

          debugPrint('Employee joined in $currentYear: ${joinDate.toString()}');
          debugPrint('Working days from join to year end: $workingDays');
          debugPrint('Daily increment: $dailyIncrement');
          debugPrint('Max allowed increase: $maxAllowedIncrease');
          debugPrint('Final actual increase: $actualIncrease');
        }
      } catch (e) {
        debugPrint('Error parsing join date "$joinDateStr": $e');
        // Continue with normal calculation if date parsing fails
      }
    }

    // Ensure actual increase is never negative - zero is the minimum value
    return actualIncrease < 0 ? 0.0 : actualIncrease;
  }

  DateTime _parseJoinDate(String dateStr) {
    // Handle various date formats
    dateStr = dateStr.trim();

    // Try different date formats
    final formats = [
      RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$'), // DD.MM.YYYY
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'), // DD/MM/YYYY
      RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$'), // YYYY-MM-DD
    ];

    for (final format in formats) {
      final match = format.firstMatch(dateStr);
      if (match != null) {
        int day, month, year;

        if (format == formats[2]) {
          // YYYY-MM-DD
          year = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          day = int.parse(match.group(3)!);
        } else {
          // DD.MM.YYYY or DD/MM/YYYY
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          year = int.parse(match.group(3)!);
        }

        return DateTime(year, month, day);
      }
    }

    throw FormatException('Unable to parse date: $dateStr');
  }

  int _calculateWorkingDaysFromJoinToYearEnd(DateTime joinDate) {
    final currentYear = joinDate.year;
    final yearEnd = DateTime(currentYear, 12, 31);

    // If join date is after year end (shouldn't happen), return 0
    if (joinDate.isAfter(yearEnd)) {
      return 0;
    }

    // Calculate the difference in days, including both start and end dates
    final difference = yearEnd.difference(joinDate).inDays + 1;

    return difference;
  }

  // Save grade changes to persist them
  Future<void> saveGradeChange(
    String badgeNo,
    String newGrade,
    String newBasicSystem,
  ) async {
    try {
      debugPrint(
        'Saving grade change: Badge=$badgeNo, Grade=$newGrade, NewBasic=$newBasicSystem',
      );

      // Ensure the appraisal table exists with correct structure
      await db.execute('''
        CREATE TABLE IF NOT EXISTS appraisal (
          badge_no TEXT PRIMARY KEY,
          grade TEXT,
          new_basic_system TEXT,
          changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Clean and validate the values
      final cleanedNewBasic = newBasicSystem.trim();
      final cleanedGrade = newGrade.trim();

      // Insert or update appraisal record
      final result = await db.insert('appraisal', {
        'badge_no': badgeNo,
        'grade': cleanedGrade,
        'new_basic_system': cleanedNewBasic,
        'changed_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      debugPrint('Successfully saved appraisal record with result: $result');

      // Verify the save
      final saved = await db.query(
        'appraisal',
        where: 'badge_no = ?',
        whereArgs: [badgeNo],
      );
      debugPrint('Verified saved data: $saved');
    } catch (e) {
      debugPrint('Error saving appraisal record: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getGradeChange(String badgeNo) async {
    try {
      final results = await db.query(
        'appraisal',
        where: 'badge_no = ?',
        whereArgs: [badgeNo],
      );

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting appraisal record: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllGradeChanges() async {
    try {
      return await db.query('appraisal', orderBy: 'changed_at DESC');
    } catch (e) {
      debugPrint('Error getting all appraisal records: $e');
      rethrow;
    }
  }
}
