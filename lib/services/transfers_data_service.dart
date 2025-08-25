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

      // Initialize transferred employees table
      await _initializeTransferredTable();
    } catch (e) {
      print('Error creating transfers table: $e');
      rethrow;
    }
  }

  Future<void> _initializeTransferredTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transferred_employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          Badge_NO TEXT NOT NULL,
          Employee_Name TEXT,
          Grade TEXT,
          Old_Position_Code TEXT,
          Old_Position TEXT,
          Current_Position_Code TEXT,
          Current_Position TEXT,
          Transfer_Type TEXT,
          POD TEXT,
          ERD TEXT,
          Available_in_ERD TEXT,
          transferred_date TEXT NOT NULL,
          created_date TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('Error creating transferred_employees table: $e');
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
      final badgeColumn =
          tableInfo.map((col) => col['name'].toString()).firstWhere(
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
      // Check if Staff_Assignments table exists (table name has underscore)
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

  // Add method to remove transfer by Badge_NO
  Future<void> removeTransferByBadgeNo(String badgeNo) async {
    try {
      print('Removing transfer for Badge_NO: $badgeNo');
      int deletedRows = await db
          .delete('transfers', where: 'Badge_NO = ?', whereArgs: [badgeNo]);
      print('Deleted $deletedRows rows for Badge_NO: $badgeNo');
    } catch (e) {
      print('Error removing transfer by Badge_NO: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransfersData() async {
    try {
      // Get all transfers from transfers table ordered by Badge_NO
      final transfers = await db.query(
        'transfers',
        orderBy: 'CAST(Badge_NO AS INTEGER) ASC',
      );

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

          // Check position occupancy in base sheet instead of Staff_Assignments
          final occupancyData = await _checkPositionOccupancyInBaseSheet(
            positionCode,
          );
          mutableTransfer['Occupancy'] = occupancyData['occupancy'];
          mutableTransfer['Badge_Number'] = occupancyData['badgeNumber'];
        } else {
          // Set empty values if position not found
          mutableTransfer['Dept'] = '';
          mutableTransfer['Position_Abbreviation'] = '';
          mutableTransfer['Position_Description'] = '';
          mutableTransfer['New_Bus_Line'] = '';
          mutableTransfer['OrgUnit_Description'] = '';
          mutableTransfer['Grade_Range6'] = '';
          mutableTransfer['Grade_GAP'] = '';
          mutableTransfer['Transfer_Type'] = '';

          // For position not found in Staff_Assignments, still check base sheet
          final occupancyData = await _checkPositionOccupancyInBaseSheet(
            positionCode,
          );
          mutableTransfer['Occupancy'] = occupancyData['occupancy'];
          mutableTransfer['Badge_Number'] = occupancyData['badgeNumber'];
        }

        processedData.add(mutableTransfer);
      }

      return processedData;
    } catch (e) {
      print('Error getting transfers data: $e');
      rethrow;
    }
  }

  // Add new method to check position occupancy in base sheet
  Future<Map<String, String>> _checkPositionOccupancyInBaseSheet(
    String positionCode,
  ) async {
    try {
      if (positionCode.isEmpty) {
        return {'occupancy': 'Vacant', 'badgeNumber': ''};
      }

      // Check if any record in base sheet has this position code in Position_Abbrv column
      final result = await db.query(
        baseTableName,
        where: '"Position_Abbrv" = ?',
        whereArgs: [positionCode],
        limit: 1,
      );

      if (result.isNotEmpty) {
        // Position is occupied
        final occupiedRecord = result.first;

        // Find the badge column name
        final tableInfo = await db.rawQuery(
          'PRAGMA table_info("$baseTableName")',
        );
        final badgeColumn =
            tableInfo.map((col) => col['name'].toString()).firstWhere(
                  (name) => name.toLowerCase().contains('badge'),
                  orElse: () => 'Badge_NO',
                );

        final badgeNumber = occupiedRecord[badgeColumn]?.toString() ?? '';

        return {'occupancy': 'Occupied', 'badgeNumber': badgeNumber};
      } else {
        // Position is vacant
        return {'occupancy': 'Vacant', 'badgeNumber': ''};
      }
    } catch (e) {
      print('Error checking position occupancy in base sheet: $e');
      return {'occupancy': 'Vacant', 'badgeNumber': ''};
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
      final badgeColumn =
          tableInfo.map((col) => col['name'].toString()).firstWhere(
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
      // Check if Staff_Assignments table exists (table name has underscore)
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
      // If Done/Yes/No is set to "Done", complete the transfer
      if (fieldName == 'DONE_YES_NO' && value.toLowerCase() == 'done') {
        await _completeTransfer(sNo);
        return;
      }

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

  Future<void> _completeTransfer(String sNo) async {
    try {
      // Get the transfer record
      final transferRecords = await db.query(
        'transfers',
        where: 'S_NO = ?',
        whereArgs: [sNo],
      );

      if (transferRecords.isEmpty) {
        throw Exception('Transfer record not found');
      }

      final transfer = transferRecords.first;
      final badgeNo = transfer['Badge_NO']?.toString() ?? '';
      final positionCode = transfer['Position_Code']?.toString() ?? '';

      // Get employee data from base sheet
      final baseData = await _getEmployeeFromBaseSheet(badgeNo);
      if (baseData == null) {
        throw Exception('Employee not found in base sheet');
      }

      // Get position data for both old and new positions
      final oldPositionData = await _getPositionFromStaffAssignments(
        baseData['Position_Abbrv']?.toString() ?? '',
      );
      final newPositionData = await _getPositionFromStaffAssignments(
        positionCode,
      );

      // Calculate transfer type
      final transferType = _calculateTransferType(
        baseData['Grade_Range']?.toString() ?? '',
        newPositionData?['Grade_Range']?.toString() ?? '',
      );

      final now = DateTime.now().toIso8601String();

      // Insert into transferred_employees table
      await db.insert('transferred_employees', {
        'Badge_NO': badgeNo,
        'Employee_Name': baseData['Employee_Name']?.toString() ?? '',
        'Grade': baseData['Grade']?.toString() ?? '',
        'Old_Position_Code': baseData['Position_Abbrv']?.toString() ?? '',
        'Old_Position': baseData['Position_Text']?.toString() ?? '',
        'Current_Position_Code': positionCode,
        'Current_Position':
            newPositionData?['Position_Description']?.toString() ?? '',
        'Transfer_Type': transferType,
        'POD': transfer['POD']?.toString() ?? '',
        'ERD': transfer['ERD']?.toString() ?? '',
        'Available_in_ERD': transfer['Available_in_ERD']?.toString() ?? '',
        'transferred_date': now,
        'created_date': now,
      });

      // Remove from transfers table
      await db.delete('transfers', where: 'S_NO = ?', whereArgs: [sNo]);
    } catch (e) {
      print('Error completing transfer: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTransferredEmployees({
    required int limit,
    required int offset,
  }) async {
    try {
      final data = await db.query(
        'transferred', // Changed from 'transferred_employees' to 'transferred'
        orderBy:
            'transfer_date DESC', // Changed from 'transferred_date' to 'transfer_date'
        limit: limit,
        offset: offset,
      );

      return data.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      print('Error getting transferred employees: $e');
      rethrow;
    }
  }

  Future<void> removeTransferredEmployee(
    String badgeNo,
    String transferredDate,
  ) async {
    try {
      // Try to delete by Badge_NO and transfer_date first
      int count = await db.delete(
        'transferred',
        where: 'Badge_NO = ? AND transfer_date = ?',
        whereArgs: [badgeNo, transferredDate],
      );

      // If no rows were deleted, try by Badge_NO only (in case transfer_date doesn't match exactly)
      if (count == 0) {
        print(
            'No rows deleted with Badge_NO and transfer_date, trying Badge_NO only');
        count = await db.delete(
          'transferred',
          where: 'Badge_NO = ?',
          whereArgs: [badgeNo],
        );
      }

      print('Deleted $count rows for Badge_NO: $badgeNo');
    } catch (e) {
      print('Error removing transferred employee: $e');
      rethrow;
    }
  }

  Future<void> clearAllTransfers() async {
    try {
      await db.delete('transfers', where: '1 = 1');
    } catch (e) {
      print('Error clearing all transfers: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addMultipleTransfers(
    List<Map<String, String>> transfers,
  ) async {
    final results = <String, dynamic>{
      'successful': <String>[],
      'failed': <Map<String, String>>[],
      'duplicateEmployees': <String>[],
      'invalidEmployees': <String>[],
      'invalidPositions': <String>[],
    };

    try {
      // Check for duplicate badge numbers in the request
      final badgeNumbers = transfers.map((t) => t['badgeNo']!).toList();
      final uniqueBadges = badgeNumbers.toSet();

      if (uniqueBadges.length != badgeNumbers.length) {
        final duplicates = <String>[];
        final seen = <String>{};
        for (final badge in badgeNumbers) {
          if (seen.contains(badge)) {
            duplicates.add(badge);
          } else {
            seen.add(badge);
          }
        }
        throw Exception(
          'أرقام الموظفين التالية مكررة في القائمة: ${duplicates.join(', ')}',
        );
      }

      // Validate all employees exist
      final validEmployees = await _validateMultipleEmployees(badgeNumbers);
      final invalidEmployees = badgeNumbers
          .where((badge) => !validEmployees.contains(badge))
          .toList();

      // Validate all positions exist
      final positionCodes = transfers.map((t) => t['positionCode']!).toList();
      final validPositions = await _validateMultiplePositions(positionCodes);
      final invalidPositions = positionCodes
          .where((position) => !validPositions.contains(position))
          .toList();

      results['invalidEmployees'] = invalidEmployees;
      results['invalidPositions'] = invalidPositions;

      // Check for existing transfers
      final existingTransfers = await _checkExistingTransfers(badgeNumbers);
      results['duplicateEmployees'] = existingTransfers;

      // Process only valid transfers
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final transfer in transfers) {
        final badgeNo = transfer['badgeNo']!;
        final positionCode = transfer['positionCode']!;

        // Skip if employee doesn't exist, position doesn't exist, or transfer already exists
        if (invalidEmployees.contains(badgeNo) ||
            invalidPositions.contains(positionCode) ||
            existingTransfers.contains(badgeNo)) {
          results['failed'].add({
            'badgeNo': badgeNo,
            'positionCode': positionCode,
            'reason': _getFailureReason(
              badgeNo,
              positionCode,
              invalidEmployees,
              invalidPositions,
              existingTransfers,
            ),
          });
          continue;
        }

        // Add to batch
        batch.insert('transfers', {
          'Badge_NO': badgeNo,
          'Position_Code': positionCode,
          'POD': '',
          'ERD': '',
          'DONE_YES_NO': '',
          'Available_in_ERD': '',
          'created_date': now,
        });

        results['successful'].add(badgeNo);
      }

      // Execute batch
      await batch.commit();

      return results;
    } catch (e) {
      print('Error adding multiple transfers: $e');
      rethrow;
    }
  }

  String _getFailureReason(
    String badgeNo,
    String positionCode,
    List<String> invalidEmployees,
    List<String> invalidPositions,
    List<String> existingTransfers,
  ) {
    final reasons = <String>[];

    if (invalidEmployees.contains(badgeNo)) {
      reasons.add('الموظف غير موجود');
    }

    if (invalidPositions.contains(positionCode)) {
      reasons.add('كود الوظيفة غير موجود');
    }

    if (existingTransfers.contains(badgeNo)) {
      reasons.add('التنقل موجود مسبقاً');
    }

    return reasons.join(', ');
  }

  Future<List<String>> _validateMultipleEmployees(
    List<String> badgeNumbers,
  ) async {
    if (badgeNumbers.isEmpty) return [];

    try {
      // Find the badge column in base table
      final tableInfo = await db.rawQuery(
        'PRAGMA table_info("$baseTableName")',
      );
      final badgeColumn =
          tableInfo.map((col) => col['name'].toString()).firstWhere(
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

  Future<List<String>> _validateMultiplePositions(
    List<String> positionCodes,
  ) async {
    if (positionCodes.isEmpty) return [];

    try {
      // Check if Staff_Assignments table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'Staff_Assignments'",
      );

      if (tableExists.isEmpty) {
        return [];
      }

      final placeholders = positionCodes.map((_) => '?').join(',');
      final result = await db.rawQuery(
        '''
        SELECT DISTINCT "Position_Abbreviation" FROM "Staff_Assignments"
        WHERE "Position_ID" IN ($placeholders) 
           OR "Position_Code" IN ($placeholders) 
           OR "Position_Abbreviation" IN ($placeholders)
      ''',
        [...positionCodes, ...positionCodes, ...positionCodes],
      );

      final validPositions = result
          .map((row) => row['Position_Abbreviation']?.toString() ?? '')
          .where((position) => position.isNotEmpty)
          .toSet();

      // Return positions that exist in the input list
      return positionCodes
          .where((position) => validPositions.contains(position))
          .toList();
    } catch (e) {
      print('Error validating multiple positions: $e');
      return [];
    }
  }

  Future<List<String>> _checkExistingTransfers(
    List<String> badgeNumbers,
  ) async {
    if (badgeNumbers.isEmpty) return [];

    try {
      final placeholders = badgeNumbers.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT DISTINCT Badge_NO FROM transfers WHERE Badge_NO IN ($placeholders)',
        badgeNumbers,
      );

      return result
          .map((row) => row['Badge_NO']?.toString() ?? '')
          .where((badge) => badge.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error checking existing transfers: $e');
      return [];
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
}
