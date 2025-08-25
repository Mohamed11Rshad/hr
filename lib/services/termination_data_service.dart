import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/category_mapper.dart';

class TerminationDataService {
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
      print('Error calculating maximum: $e');
      return 0.0;
    }
  }

  final Database db;
  final String baseTableName;

  TerminationDataService({required this.db, required this.baseTableName});

  Future<void> initializeTerminationTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS terminations (
          S_NO INTEGER PRIMARY KEY AUTOINCREMENT,
          Badge_NO TEXT NOT NULL,
          Termination_Date TEXT NOT NULL,
          Appraisal_Text TEXT DEFAULT '',
          created_date TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Add Appraisal_Text column if it doesn't exist
      try {
        await db.execute('''
          ALTER TABLE terminations ADD COLUMN Appraisal_Text TEXT DEFAULT ''
        ''');
      } catch (e) {
        // Column might already exist
        print('Appraisal_Text column might already exist: $e');
      }
    } catch (e) {
      print('Error creating terminations table: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addTermination(
    String badgeNo,
    String terminationDate,
    String appraisalText,
  ) async {
    try {
      // Validate employee exists in base sheet
      final employeeExists = await _validateEmployeeExists(badgeNo);
      if (!employeeExists) {
        return {
          'success': false,
          'message': 'Employee with Badge No $badgeNo not found in base sheet',
        };
      }

      // Check if employee already has termination record
      final existing = await db.query(
        'terminations',
        where: 'Badge_NO = ?',
        whereArgs: [badgeNo],
      );

      if (existing.isNotEmpty) {
        return {
          'success': false,
          'message': 'Employee $badgeNo already has termination record',
        };
      }

      await db.insert('terminations', {
        'Badge_NO': badgeNo,
        'Termination_Date': terminationDate,
        'Appraisal_Text': appraisalText,
        'created_date': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Termination record added successfully',
      };
    } catch (e) {
      print('Error adding termination: $e');
      return {
        'success': false,
        'message': 'Error adding termination: ${e.toString()}',
      };
    }
  }

  Future<bool> _validateEmployeeExists(String badgeNo) async {
    try {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info("$baseTableName")',
      );
      final badgeColumn = tableInfo
          .map((col) => col['name'].toString())
          .firstWhere(
            (name) => name.toLowerCase().contains('badge'),
            orElse: () => 'Badge_NO',
          );

      final result = await db.query(
        baseTableName,
        where: '"$badgeColumn" = ?',
        whereArgs: [badgeNo],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('Error validating employee exists: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTerminationsData() async {
    try {
      final terminations = await db.query(
        'terminations',
        orderBy: 'CAST(Badge_NO AS INTEGER) ASC',
      );

      if (terminations.isEmpty) {
        return [];
      }

      final processedData = <Map<String, dynamic>>[];

      for (final termination in terminations) {
        final mutableTermination = Map<String, dynamic>.from(termination);
        final badgeNo = termination['Badge_NO']?.toString() ?? '';
        final terminationDate =
            termination['Termination_Date']?.toString() ?? '';
        final appraisalText = termination['Appraisal_Text']?.toString() ?? '';

        // Get employee data from base sheet
        final baseData = await _getEmployeeFromBaseSheet(badgeNo);
        if (baseData != null) {
          mutableTermination['Employee_Name'] = baseData['Employee_Name'] ?? '';
          mutableTermination['Grade'] = _formatAsInteger(
            baseData['Grade']?.toString() ?? '',
          );
          mutableTermination['Old_Basic'] = _formatAsInteger(
            baseData['Basic']?.toString() ?? '',
          );

          // Calculate Adjust NO of Months
          final adjustMonths = await _calculateAdjustMonths(
            baseData,
            terminationDate,
          );
          mutableTermination['Adjust_Months'] = adjustMonths.toStringAsFixed(2);

          // Calculate Adjustment
          final adjustment = await _calculateAdjustment(baseData, adjustMonths);
          mutableTermination['Adjustment'] = adjustment.toStringAsFixed(2);

          // Calculate Old Basic + Adj
          final oldBasic =
              double.tryParse(baseData['Basic']?.toString() ?? '0')?.round() ??
              0;
          final oldBasicPlusAdj = oldBasic + adjustment;
          mutableTermination['Old_Basic_Plus_Adj'] =
              oldBasicPlusAdj.round().toString();

          // Calculate Adjust.Date (first day of month before termination month)
          mutableTermination['Adjust_Date'] = _calculateAdjustDate(
            terminationDate,
          );

          // Set Appraisal Text (editable field)
          mutableTermination['Appraisal_Text'] = appraisalText;

          // Calculate Annual Increment from promotions logic
          final annualIncrement = await _calculateAnnualIncrement(
            baseData,
            terminationDate,
            appraisalText,
          );
          mutableTermination['Annual_Increment'] =
              annualIncrement.round().toString();

          // Calculate Appraisal NO of Months (Term/Date - one day) month
          final appraisalMonths = _calculateAppraisalMonths(terminationDate);
          mutableTermination['Appraisal_NO_of_Months'] =
              appraisalMonths.toString();

          // Calculate Appraisal Amount: (annual increment/12) * Appraisal No of Months
          final appraisalAmount = _calculateAppraisalAmount(
            annualIncrement,
            appraisalMonths,
          );
          mutableTermination['Appraisal_Amount'] =
              appraisalAmount.round().toString();

          // Calculate Appraisal Date
          final appraisalDate = _calculateAppraisalDate(terminationDate);
          mutableTermination['Appraisal_Date'] = appraisalDate;

          // Calculate New Basic: Appraisal amount + Old Basic + Adj
          final newBasic = _calculateNewBasic(
            oldBasic.toDouble(),
            adjustment,
            appraisalAmount.toDouble(),
          );
          mutableTermination['New_Basic'] = newBasic.toStringAsFixed(2);

          // Calculate Current Lump sum (using appraisal sheet logic)
          // Get employee data with appraisal grade for lump sum calculation
          final baseDataWithAppraisalGrade =
              await _getEmployeeWithAppraisalGrade(badgeNo);
          if (baseDataWithAppraisalGrade != null) {
            final appraisalAnnualIncrement =
                await _calculateAnnualIncrementForCurrentGrade(
                  baseDataWithAppraisalGrade,
                );
            final maximum = await _calculateMaximumForCurrentGrade(
              baseDataWithAppraisalGrade,
            );
            final actualIncrease = _calculateActualIncrease(
              oldBasic.toDouble(),
              appraisalAnnualIncrement,
              maximum.toDouble(),
              baseDataWithAppraisalGrade,
            );
            debugPrint(
              "------------------- appraisalAnnualIncrement: $appraisalAnnualIncrement",
            );
            debugPrint("------------------- actualIncrease: $actualIncrease");

            final currentLumpSum = appraisalAnnualIncrement - actualIncrease;
            mutableTermination['Current_Lump_Sum'] = currentLumpSum
                .toStringAsFixed(2);

            // Amount/12
            final amountDiv12 = currentLumpSum / 12;
            mutableTermination['Amount_Div_12'] = amountDiv12.toStringAsFixed(
              2,
            );

            // (Amount/12)/Month
            final amountDiv12PerMonth = amountDiv12 / 31;
            mutableTermination['Amount_Div_12_Per_Month'] = amountDiv12PerMonth
                .toStringAsFixed(4);

            // Calculate No of Months: the previous month of month in date in TERM/DATE
            final noOfMonths = _calculateNoOfMonths(terminationDate);
            mutableTermination['No_of_Months'] = noOfMonths.toString();

            // Calculate No of Days: days in TERM/DATE - 1
            final noOfDays = _calculateNoOfDays(terminationDate);
            mutableTermination['No_of_Days'] = noOfDays.toString();

            // Calculate New Lump Sum: (Amount/12) * (No of Months) + ((Amount/12)/Month) * No of Days
            final newLumpSum = _calculateNewLumpSum(
              amountDiv12,
              amountDiv12PerMonth,
              noOfMonths,
              noOfDays,
            );
            mutableTermination['New_Lump_Sum'] = newLumpSum.toStringAsFixed(2);
          } else {
            // Fallback if appraisal grade data not found
            mutableTermination['Current_Lump_Sum'] = '0.00';
            mutableTermination['Amount_Div_12'] = '0.00';
            mutableTermination['Amount_Div_12_Per_Month'] = '0.0000';
            mutableTermination['No_of_Months'] = '0';
            mutableTermination['No_of_Days'] = '0';
            mutableTermination['New_Lump_Sum'] = '0.00';
          }
        } else {
          // Set default values if employee not found
          mutableTermination['Employee_Name'] = '';
          mutableTermination['Grade'] = '';
          mutableTermination['Old_Basic'] = '';
          mutableTermination['Adjust_Months'] = '0.00';
          mutableTermination['Adjustment'] = '0.00';
          mutableTermination['Old_Basic_Plus_Adj'] = '0';
          mutableTermination['Adjust_Date'] = '';
          mutableTermination['Appraisal_Text'] = appraisalText;
          mutableTermination['Annual_Increment'] = '0';
          mutableTermination['Appraisal_NO_of_Months'] = '0';
          mutableTermination['Appraisal_Amount'] = '0';
          mutableTermination['Appraisal_Date'] = '';
          mutableTermination['New_Basic'] = '0';
          mutableTermination['Current_Lump_Sum'] = '0.00';
          mutableTermination['Amount_Div_12'] = '0.00';
          mutableTermination['Amount_Div_12_Per_Month'] = '0.0000';
          mutableTermination['No_of_Months'] = '0';
          mutableTermination['No_of_Days'] = '0';
          mutableTermination['New_Lump_Sum'] = '0.00';
        }

        processedData.add(mutableTermination);
      }

      return processedData;
    } catch (e) {
      print('Error getting terminations data: $e');
      rethrow;
    }
  }

  String _calculateAdjustDate(String terminationDate) {
    try {
      if (terminationDate.isEmpty) return '';

      final termDate = _parseDate(terminationDate);

      // Get the month before termination month
      DateTime adjustDate;
      if (termDate.month == 1) {
        // If January, go to December of previous year
        adjustDate = DateTime(termDate.year - 1, 12, 1);
      } else {
        // Otherwise, go to previous month
        adjustDate = DateTime(termDate.year, termDate.month - 1, 1);
      }

      // Format as dd.MM.yyyy
      return '${adjustDate.day.toString().padLeft(2, '0')}.${adjustDate.month.toString().padLeft(2, '0')}.${adjustDate.year}';
    } catch (e) {
      print('Error calculating adjust date: $e');
      return '';
    }
  }

  int _calculateAppraisalMonths(String terminationDate) {
    try {
      if (terminationDate.isEmpty) return 0;

      final termDate = _parseDate(terminationDate);

      // Calculate (Term/Date - one day) month
      final oneDayBefore = termDate.subtract(const Duration(days: 1));

      return oneDayBefore.month;
    } catch (e) {
      print('Error calculating appraisal months: $e');
      return 0;
    }
  }

  Future<double> _calculateAnnualIncrement(
    Map<String, dynamic> baseData,
    String terminationDate,
    String appraisalText,
  ) async {
    try {
      // Use similar logic to promotions calculation
      final grade = baseData['Grade']?.toString() ?? '';
      if (grade.isEmpty) return 0.0;

      final currentGrade =
          int.tryParse(grade.replaceAll(RegExp(r'^0+'), '')) ?? 0;

      // Determine salary scale and annual increase tables using CategoryMapper
      final payScaleArea = baseData['Pay_scale_area_text']?.toString() ?? '';
      final annualIncreaseTable = CategoryMapper.getAnnualIncreaseTable(
        payScaleArea,
      );
      final salaryScaleTable = CategoryMapper.getSalaryScaleTable(payScaleArea);

      // Get salary scale data for midpoint calculation
      final salaryScaleData = await db.query(
        salaryScaleTable,
        where: 'Grade = ?',
        whereArgs: [currentGrade],
      );

      if (salaryScaleData.isEmpty) return 0.0;

      final midpoint =
          double.tryParse(
            salaryScaleData.first['midpoint']?.toString() ?? '0',
          ) ??
          0;

      // Determine midpoint status
      final oldBasic =
          double.tryParse(baseData['Basic']?.toString() ?? '0')?.round() ?? 0;
      final fourPercentAdj = oldBasic * 0.04;
      final oldBasePlusAdj = oldBasic + fourPercentAdj;
      final midpointStatus = (oldBasePlusAdj < midpoint) ? 'b' : 'a';

      // Get annual increase data - use provided appraisal text or default to '3'
      var appraisalValue = appraisalText.isNotEmpty ? appraisalText : 'O';

      final annualIncreaseData = await db.query(
        annualIncreaseTable,
        where: 'Grade = ?',
        whereArgs: [currentGrade],
      );

      if (annualIncreaseData.isEmpty) return 0.0;

      final potentialIncrement =
          double.tryParse(
            annualIncreaseData.first['${appraisalValue}_$midpointStatus']
                    ?.toString() ??
                '0',
          ) ??
          0;

      return potentialIncrement < 0 ? 0 : potentialIncrement;
    } catch (e) {
      print('Error calculating annual increment: $e');
      return 0.0;
    }
  }

  // Calculate annual increment using appraisal logic (for lump sum calculation)
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
      debugPrint('Error calculating annual increment for current grade: $e');
      return 0.0;
    }
  }

  // Add method to update appraisal text
  Future<void> updateAppraisalText(String sNo, String appraisalText) async {
    try {
      await db.update(
        'terminations',
        {'Appraisal_Text': appraisalText},
        where: 'S_NO = ?',
        whereArgs: [sNo],
      );
    } catch (e) {
      print('Error updating appraisal text: $e');
      rethrow;
    }
  }

  Future<void> removeTermination(String sNo) async {
    try {
      await db.delete('terminations', where: 'S_NO = ?', whereArgs: [sNo]);
    } catch (e) {
      print('Error removing termination: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addMultipleTerminations(
    List<Map<String, String>> terminations,
  ) async {
    final results = <String, dynamic>{
      'successful': <String>[],
      'failed': <Map<String, String>>[],
      'duplicateEmployees': <String>[],
      'invalidEmployees': <String>[],
    };

    try {
      final badgeNumbers = terminations.map((t) => t['badgeNo']!).toList();

      // Validate employees exist
      final validEmployees = await _validateMultipleEmployees(badgeNumbers);
      final invalidEmployees =
          badgeNumbers
              .where((badge) => !validEmployees.contains(badge))
              .toList();

      // Check for existing terminations
      final existingTerminations = await _checkExistingTerminations(
        badgeNumbers,
      );

      results['invalidEmployees'] = invalidEmployees;
      results['duplicateEmployees'] = existingTerminations;

      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final termination in terminations) {
        final badgeNo = termination['badgeNo']!;
        final terminationDate = termination['terminationDate']!;
        final appraisalText = termination['appraisalText'] ?? '';

        if (invalidEmployees.contains(badgeNo) ||
            existingTerminations.contains(badgeNo)) {
          results['failed'].add({
            'badgeNo': badgeNo,
            'terminationDate': terminationDate,
            'reason': _getFailureReason(
              badgeNo,
              invalidEmployees,
              existingTerminations,
            ),
          });
          continue;
        }

        batch.insert('terminations', {
          'Badge_NO': badgeNo,
          'Termination_Date': terminationDate,
          'Appraisal_Text': appraisalText,
          'created_date': now,
        });

        results['successful'].add(badgeNo);
      }

      await batch.commit();
      return results;
    } catch (e) {
      print('Error adding multiple terminations: $e');
      rethrow;
    }
  }

  Future<List<String>> _validateMultipleEmployees(
    List<String> badgeNumbers,
  ) async {
    if (badgeNumbers.isEmpty) return [];

    try {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info("$baseTableName")',
      );
      final badgeColumn = tableInfo
          .map((col) => col['name'].toString())
          .firstWhere(
            (name) => name.toLowerCase().contains('badge'),
            orElse: () => 'Badge_NO',
          );

      final placeholders = badgeNumbers.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT DISTINCT "$badgeColumn" FROM "$baseTableName" WHERE "$badgeColumn" IN ($placeholders)',
        badgeNumbers,
      );

      return result
          .map((row) => row[badgeColumn]?.toString() ?? '')
          .where((badge) => badge.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error validating multiple employees: $e');
      return [];
    }
  }

  Future<List<String>> _checkExistingTerminations(
    List<String> badgeNumbers,
  ) async {
    if (badgeNumbers.isEmpty) return [];

    try {
      final placeholders = badgeNumbers.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT DISTINCT Badge_NO FROM terminations WHERE Badge_NO IN ($placeholders)',
        badgeNumbers,
      );

      return result
          .map((row) => row['Badge_NO']?.toString() ?? '')
          .where((badge) => badge.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error checking existing terminations: $e');
      return [];
    }
  }

  String _getFailureReason(
    String badgeNo,
    List<String> invalidEmployees,
    List<String> existingTerminations,
  ) {
    final reasons = <String>[];

    if (invalidEmployees.contains(badgeNo)) {
      reasons.add('الموظف غير موجود');
    }

    if (existingTerminations.contains(badgeNo)) {
      reasons.add('يوجد تسجيل مسبق للموظف');
    }

    return reasons.join(', ');
  }

  // Add missing helper methods
  Future<Map<String, dynamic>?> _getEmployeeFromBaseSheet(
    String badgeNo,
  ) async {
    try {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info("$baseTableName")',
      );
      final badgeColumn = tableInfo
          .map((col) => col['name'].toString())
          .firstWhere(
            (name) => name.toLowerCase().contains('badge'),
            orElse: () => 'Badge_NO',
          );

      final result = await db.query(
        baseTableName,
        where: '"$badgeColumn" = ?',
        whereArgs: [badgeNo],
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting employee from base sheet: $e');
      return null;
    }
  }

  // Get employee data with appraisal grade for lump sum calculation only
  Future<Map<String, dynamic>?> _getEmployeeWithAppraisalGrade(
    String badgeNo,
  ) async {
    try {
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info("$baseTableName")',
      );
      final badgeColumn = tableInfo
          .map((col) => col['name'].toString())
          .firstWhere(
            (name) => name.toLowerCase().contains('badge'),
            orElse: () => 'Badge_NO',
          );

      // Use the same logic as appraisal service to get grade from appraisal table if exists
      final query = '''
        SELECT b.*, 
               COALESCE(a_table.grade, b.Grade) as Grade,
               COALESCE(a_table.new_basic_system, '') as New_Basic_System
        FROM "$baseTableName" b
        LEFT JOIN appraisal a_table ON b."$badgeColumn" = a_table.badge_no
        WHERE b."$badgeColumn" = ?
        LIMIT 1
        ''';

      final result = await db.rawQuery(query, [badgeNo]);

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting employee with appraisal grade: $e');
      return null;
    }
  }

  String _formatAsInteger(String value) {
    if (value.isEmpty) return '';

    try {
      final doubleValue = double.tryParse(value) ?? 0;
      return doubleValue.round().toString();
    } catch (e) {
      print('Error formatting as integer: $e');
      return value;
    }
  }

  Future<double> _calculateAdjustMonths(
    Map<String, dynamic> baseData,
    String terminationDate,
  ) async {
    try {
      if (terminationDate.isEmpty) return 0.0;

      final termDate = _parseDate(terminationDate);
      final lastPromotionDate = _parseDate(
        baseData['Last_Promotion_Dt']?.toString() ?? '',
      );

      if (lastPromotionDate.year == 1900) return 0.0; // Invalid date

      // Calculate months between last promotion and termination (with decimal precision)
      final yearsDiff = termDate.year - lastPromotionDate.year;
      final monthsDiff = termDate.month - lastPromotionDate.month;
      final daysDiff = termDate.day - lastPromotionDate.day;

      // Calculate total months with decimal precision
      double totalMonths = (yearsDiff * 12).toDouble() + monthsDiff.toDouble();

      // Add fractional month based on days
      if (daysDiff != 0) {
        final daysInMonth = DateTime(termDate.year, termDate.month + 1, 0).day;
        totalMonths += daysDiff / daysInMonth;
      }

      return totalMonths > 0 ? totalMonths : 0.0;
    } catch (e) {
      print('Error calculating adjust months: $e');
      return 0.0;
    }
  }

  Future<double> _calculateAdjustment(
    Map<String, dynamic> baseData,
    double adjustMonths,
  ) async {
    try {
      if (adjustMonths == 0.0) return 0.0;

      // Get current grade and calculate next grade
      var currentGrade = baseData['Grade']?.toString() ?? '';
      if (currentGrade.isEmpty) return 0.0;

      // Remove leading zeros if present
      if (currentGrade.startsWith('0')) {
        currentGrade = currentGrade.substring(1);
      }

      // Calculate next grade (current grade + 1)
      final currentGradeNum = int.tryParse(currentGrade) ?? 0;
      final nextGrade = (currentGradeNum + 1).toString();
      debugPrint('///////////////////////Next Grade: $nextGrade');

      // Get midpoint for next grade
      final nextGradeMidpoint = await _getMidpointForGrade(baseData, nextGrade);

      debugPrint(
        '///////////////////////Next Grade Midpoint: $nextGradeMidpoint',
      );

      if (nextGradeMidpoint == 0.0) return 0.0;

      // New formula: (midpoint × adj_months × 4/100) / 48
      final result = (nextGradeMidpoint * adjustMonths * 4 / 100) / 48;

      debugPrint('///////////////////////Adjustment Result: $result');

      return result;
    } catch (e) {
      print('Error calculating adjustment: $e');
      return 0.0;
    }
  }

  Future<double> _getMidpointForGrade(
    Map<String, dynamic> baseData,
    String grade,
  ) async {
    try {
      // Determine salary scale table using CategoryMapper
      final payScaleArea = baseData['Pay_scale_area_text']?.toString() ?? '';
      final salaryScaleTable = CategoryMapper.getSalaryScaleTable(payScaleArea);

      // Get salary scale data for midpoint calculation
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
      print('Error getting midpoint for grade: $e');
      return 0.0;
    }
  }

  int _calculateAppraisalAmount(double annualIncrement, int appraisalMonths) {
    try {
      if (annualIncrement == 0 || appraisalMonths == 0) return 0;

      // (annual increment/12) * Appraisal No of Months
      return ((annualIncrement / 12) * appraisalMonths).round();
    } catch (e) {
      print('Error calculating appraisal amount: $e');
      return 0;
    }
  }

  String _calculateAppraisalDate(String terminationDate) {
    try {
      if (terminationDate.isEmpty) return '';

      final termDate = _parseDate(terminationDate);

      // Check if Term/Date is the first day of the month
      if (termDate.day == 1) {
        // If it's the first day, go to the first day of the previous month
        DateTime appraisalDate;
        if (termDate.month == 1) {
          // If January, go to December of previous year
          appraisalDate = DateTime(termDate.year - 1, 12, 1);
        } else {
          // Otherwise, go to previous month
          appraisalDate = DateTime(termDate.year, termDate.month - 1, 1);
        }

        // Format as dd.MM.yyyy
        return '${appraisalDate.day.toString().padLeft(2, '0')}.${appraisalDate.month.toString().padLeft(2, '0')}.${appraisalDate.year}';
      } else {
        // If it's not the first day, use the first day of the Term/Date month
        final appraisalDate = DateTime(termDate.year, termDate.month, 1);

        // Format as dd.MM.yyyy
        return '${appraisalDate.day.toString().padLeft(2, '0')}.${appraisalDate.month.toString().padLeft(2, '0')}.${appraisalDate.year}';
      }
    } catch (e) {
      print('Error calculating appraisal date: $e');
      return '';
    }
  }

  double _calculateNewBasic(
    double oldBasic,
    double adjustment,
    double appraisalAmount,
  ) {
    try {
      // New Basic = Appraisal amount + Old Basic + Adj
      return appraisalAmount + oldBasic + adjustment;
    } catch (e) {
      print('Error calculating new basic: $e');
      return 0.0;
    }
  }

  DateTime _parseDate(String dateString) {
    if (dateString.isEmpty) {
      return DateTime(1900); // Very old date for comparison
    }

    try {
      if (dateString.contains('.')) {
        final parts = dateString.split('.');
        if (parts.length >= 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length >= 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else if (dateString.contains('-')) {
        final parts = dateString.split('-');
        if (parts.length >= 3) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } else {
        return DateTime.parse(dateString);
      }
    } catch (e) {
      print('Error parsing date "$dateString": $e');
    }

    return DateTime(1900); // Fallback date
  }

  // Calculate No of Months: the previous month of month in date in TERM/DATE
  int _calculateNoOfMonths(String terminationDate) {
    try {
      if (terminationDate.isEmpty) return 0;

      final termDate = _parseDate(terminationDate);

      // Get the previous month
      int previousMonth;
      if (termDate.month == 1) {
        previousMonth = 12; // December of previous year
      } else {
        previousMonth = termDate.month - 1;
      }

      return previousMonth;
    } catch (e) {
      print('Error calculating no of months: $e');
      return 0;
    }
  }

  // Calculate No of Days: days in TERM/DATE - 1
  int _calculateNoOfDays(String terminationDate) {
    try {
      if (terminationDate.isEmpty) return 0;

      final termDate = _parseDate(terminationDate);

      // Return days - 1
      return termDate.day - 1;
    } catch (e) {
      print('Error calculating no of days: $e');
      return 0;
    }
  }

  // Calculate New Lump Sum: (Amount/12) * (No of Months) + ((Amount/12)/Month) * No of Days
  double _calculateNewLumpSum(
    double amountDiv12,
    double amountDiv12PerMonth,
    int noOfMonths,
    int noOfDays,
  ) {
    try {
      final monthlyAmount = amountDiv12 * noOfMonths;
      final dailyAmount = amountDiv12PerMonth * noOfDays;

      return monthlyAmount + dailyAmount;
    } catch (e) {
      print('Error calculating new lump sum: $e');
      return 0.0;
    }
  }
}
