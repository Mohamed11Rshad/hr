import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TransfersDataService {
  final Database db;
  final String baseTableName;

  TransfersDataService({required this.db, required this.baseTableName});

  Future<void> initializeTransfersTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transfers (
          S_NO INTEGER PRIMARY KEY AUTOINCREMENT,
          Badge_NO TEXT NOT NULL,
          Position_Code TEXT NOT NULL,
          POD TEXT,
          ERD TEXT,
          DONE_YES_NO TEXT,
          Available_in_ERD TEXT,
          created_date TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('Error creating transfers table: $e');
      rethrow;
    }
  }

  Future<void> addTransfer(String badgeNo, String positionCode) async {
    try {
      // Validate badge number exists in base sheet
      final employeeExists = await _validateEmployeeExists(badgeNo);
      if (!employeeExists) {
        throw Exception(
          'Employee with Badge No $badgeNo not found in base sheet',
        );
      }

      // Validate position code exists in Staff_Assignments
      final positionExists = await _validatePositionExists(positionCode);
      if (!positionExists) {
        throw Exception(
          'Position Code $positionCode not found in Staff Assignments',
        );
      }

      await db.insert('transfers', {
        'Badge_NO': badgeNo,
        'Position_Code': positionCode,
        'POD': '',
        'ERD': '',
        'DONE_YES_NO': '',
        'Available_in_ERD': '',
        'created_date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding transfer: $e');
      rethrow;
    }
  }

  Future<bool> _validateEmployeeExists(String badgeNo) async {
    try {
      // Find the badge column in base table
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

  Future<bool> _validatePositionExists(String positionCode) async {
    try {
      // Check if Staff_Assignments table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'Staff_Assignments'",
      );

      if (tableExists.isEmpty) {
        return false;
      }

      // Query by Position_ID or Position_Code - try both since we're not sure which column exists
      final result = await db.rawQuery(
        '''
        SELECT * FROM "Staff_Assignments"
        WHERE "Position_ID" = ? OR "Position_Code" = ? OR "Position_Abbreviation" = ?
        LIMIT 1
      ''',
        [positionCode, positionCode, positionCode],
      );

      return result.isNotEmpty;
    } catch (e) {
      print('Error validating position exists: $e');
      return false;
    }
  }

  Future<void> removeTransfer(String sNo) async {
    try {
      await db.delete('transfers', where: 'S_NO = ?', whereArgs: [sNo]);
    } catch (e) {
      print('Error removing transfer: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransfersData() async {
    try {
      // Get all transfers from transfers table
      final transfers = await db.query('transfers', orderBy: 'S_NO');

      if (transfers.isEmpty) {
        return [];
      }

      final processedData = <Map<String, dynamic>>[];

      for (final transfer in transfers) {
        final mutableTransfer = Map<String, dynamic>.from(transfer);
        final badgeNo = transfer['Badge_NO']?.toString() ?? '';
        final positionCode = transfer['Position_Code']?.toString() ?? '';

        // Get employee data from base sheet
        final baseData = await _getEmployeeFromBaseSheet(badgeNo);
        if (baseData != null) {
          // Merge base sheet data with transfer data
          mutableTransfer['Employee_Name'] = baseData['Employee_Name'] ?? '';
          mutableTransfer['Bus_Line'] = baseData['Bus_Line'] ?? '';
          mutableTransfer['Depart_Text'] = baseData['Depart_Text'] ?? '';
          mutableTransfer['Grade'] = _formatAsInteger(
            baseData['Grade']?.toString() ?? '',
          );
          mutableTransfer['Grade_Range'] = baseData['Grade_Range'] ?? '';
          mutableTransfer['Position_Text'] = baseData['Position_Text'] ?? '';

          // Get Position Code from base sheet (Position_Abbrv)
          mutableTransfer['Emp_Position_Code'] =
              baseData['Position_Abbrv'] ?? '';
        }

        // Get position data from Staff_Assignments table based on Position_Code from dialog
        final positionData = await _getPositionFromStaffAssignments(
          positionCode,
        );
        if (positionData != null) {
          // Add Staff Assignments data
          mutableTransfer['Dept'] = positionData['Dept'] ?? '';
          mutableTransfer['Position_Abbreviation'] =
              positionData['Position_Abbreviation'] ?? '';
          mutableTransfer['Position_Description'] =
              positionData['Position_Description'] ?? '';
          mutableTransfer['OrgUnit_Description'] =
              positionData['OrgUnit_Description'] ?? '';
          mutableTransfer['Grade_Range6'] = positionData['Grade_Range'] ?? '';
          mutableTransfer['Occupancy'] = positionData['Occupancy'] ?? '';
          mutableTransfer['Badge_Number'] = positionData['Badge_Number'] ?? '';

          // Calculate New Bus Line based on Dept value
          mutableTransfer['New_Bus_Line'] = await _getBusLineFromDept(
            mutableTransfer['Dept']?.toString() ?? '',
          );

          // Calculate Grade GAP
          mutableTransfer['Grade_GAP'] = _calculateGradeGap(
            mutableTransfer['Grade']?.toString() ?? '',
            mutableTransfer['Grade_Range6']?.toString() ?? '',
          );

          // Calculate Transfer Type
          mutableTransfer['Transfer_Type'] = _calculateTransferType(
            mutableTransfer['Grade_Range']?.toString() ?? '',
            mutableTransfer['Grade_Range6']?.toString() ?? '',
          );
        } else {
          // Set empty values if position not found
          mutableTransfer['Dept'] = '';
          mutableTransfer['Position_Abbreviation'] = '';
          mutableTransfer['Position_Description'] = '';
          mutableTransfer['New_Bus_Line'] = '';
          mutableTransfer['OrgUnit_Description'] = '';
          mutableTransfer['Grade_Range6'] = '';
          mutableTransfer['Occupancy'] = '';
          mutableTransfer['Badge_Number'] = '';
          mutableTransfer['Grade_GAP'] = '';
          mutableTransfer['Transfer_Type'] = '';
        }

        processedData.add(mutableTransfer);
      }

      return processedData;
    } catch (e) {
      print('Error getting transfers data: $e');
      rethrow;
    }
  }

  // Add method to get Bus Line from Dept value
  Future<String> _getBusLineFromDept(String deptValue) async {
    if (deptValue.isEmpty) {
      return '';
    }

    try {
      // Search in base sheet for first record that starts with dept value in Depart_Text column
      final result = await db.rawQuery(
        '''
        SELECT "Bus_Line" FROM "$baseTableName"
        WHERE "Depart_Text" LIKE ?
        LIMIT 1
      ''',
        ['$deptValue%'],
      );

      if (result.isNotEmpty) {
        return result.first['Bus_Line']?.toString() ?? '';
      }

      return '';
    } catch (e) {
      print('Error getting bus line from dept: $e');
      return '';
    }
  }

  // Add method to calculate Grade GAP
  String _calculateGradeGap(String employeeGrade, String gradeRange6) {
    if (employeeGrade.isEmpty || gradeRange6.isEmpty) {
      return '';
    }

    try {
      // Parse employee grade (remove leading zeros)
      final employeeGradeInt = int.tryParse(
        employeeGrade.replaceAll(RegExp(r'^0+'), ''),
      );
      if (employeeGradeInt == null) return '';

      // Extract first number from Grade_Range6 (format: 008-013)
      final rangeParts = gradeRange6.split('-');
      if (rangeParts.isEmpty) return '';

      final firstRangeNumber = int.tryParse(
        rangeParts[0].replaceAll(RegExp(r'^0+'), ''),
      );
      if (firstRangeNumber == null) return '';

      // Compare and return result
      return employeeGradeInt < firstRangeNumber ? 'GAP' : 'NO GAP';
    } catch (e) {
      print('Error calculating grade gap: $e');
      return '';
    }
  }

  // Add method to calculate Transfer Type
  String _calculateTransferType(String gradeRange, String gradeRange6) {
    if (gradeRange.isEmpty || gradeRange6.isEmpty) {
      return '';
    }

    try {
      // Extract second number from Grade_Range (format: 008-013)
      final gradeRangeParts = gradeRange.split('-');
      if (gradeRangeParts.length < 2) return '';

      final gradeRangeSecond = int.tryParse(
        gradeRangeParts[1].replaceAll(RegExp(r'^0+'), ''),
      );
      if (gradeRangeSecond == null) return '';

      // Extract second number from Grade_Range6 (format: 008-013)
      final gradeRange6Parts = gradeRange6.split('-');
      if (gradeRange6Parts.length < 2) return '';

      final gradeRange6Second = int.tryParse(
        gradeRange6Parts[1].replaceAll(RegExp(r'^0+'), ''),
      );
      if (gradeRange6Second == null) return '';

      // Compare and return result
      if (gradeRange6Second > gradeRangeSecond) {
        return 'Higher Band';
      } else if (gradeRange6Second < gradeRangeSecond) {
        return 'Lower Band';
      } else {
        return 'Same Band';
      }
    } catch (e) {
      print('Error calculating transfer type: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>?> _getEmployeeFromBaseSheet(
    String badgeNo,
  ) async {
    try {
      // Find the badge column in base table
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

  Future<Map<String, dynamic>?> _getPositionFromStaffAssignments(
    String positionCode,
  ) async {
    try {
      // Check if Staff_Assignments table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'Staff_Assignments'",
      );

      if (tableExists.isEmpty) {
        return null;
      }

      // Query by Position_ID or Position_Code - try both since we're not sure which column exists
      final result = await db.rawQuery(
        '''
        SELECT * FROM "Staff_Assignments"
        WHERE "Position_ID" = ? OR "Position_Code" = ? OR "Position_Abbreviation" = ?
        LIMIT 1
      ''',
        [positionCode, positionCode, positionCode],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting position from staff assignments: $e');
      return null;
    }
  }

  String _formatAsInteger(String value) {
    if (value.isEmpty) {
      return '';
    }

    try {
      final doubleValue = double.tryParse(value) ?? 0;
      return doubleValue.round().toString();
    } catch (e) {
      print('Error formatting as integer: $e');
      return value; // Return original value if parsing fails
    }
  }

  // Add method to update editable fields
  Future<void> updateTransferField(
    String sNo,
    String fieldName,
    String value,
  ) async {
    try {
      await db.update(
        'transfers',
        {fieldName: value},
        where: 'S_NO = ?',
        whereArgs: [sNo],
      );
    } catch (e) {
      print('Error updating transfer field: $e');
      rethrow;
    }
  }
}
