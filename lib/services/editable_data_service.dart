import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class EditableDataService {
  final Database db;
  static const String _tableName = 'editable_data';

  EditableDataService(this.db);

  Future<void> initializeEditableDataTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          badge_no TEXT NOT NULL,
          employee_name TEXT,
          screen_type TEXT NOT NULL,
          column_name TEXT NOT NULL,
          value TEXT,
          timestamp TEXT NOT NULL,
          user_action TEXT DEFAULT 'Manual_Edit'
        )
      ''');

      print('Editable data table initialized successfully');
    } catch (e) {
      print('Error initializing editable data table: $e');
      throw Exception('Failed to initialize editable data table: $e');
    }
  }

  Future<void> saveEditableData({
    required String badgeNo,
    required String employeeName,
    required String screenType,
    required String columnName,
    required String value,
    required DateTime timestamp,
  }) async {
    try {
      // Delete existing entry for this badge, screen, and column
      await db.delete(
        _tableName,
        where: 'badge_no = ? AND screen_type = ? AND column_name = ?',
        whereArgs: [badgeNo, screenType, columnName],
      );

      // Insert new value
      await db.insert(_tableName, {
        'badge_no': badgeNo,
        'employee_name': employeeName,
        'screen_type': screenType,
        'column_name': columnName,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
        'user_action': 'Manual_Edit',
      });

      print('Saved editable data: $badgeNo - $columnName = $value');
    } catch (e) {
      print('Error saving editable data: $e');
      throw Exception('Failed to save editable data: $e');
    }
  }

  Future<Map<String, String>> getEditableData({
    required String badgeNo,
    required String screenType,
  }) async {
    try {
      final results = await db.query(
        _tableName,
        where: 'badge_no = ? AND screen_type = ?',
        whereArgs: [badgeNo, screenType],
      );

      final editableData = <String, String>{};
      for (final row in results) {
        final columnName = row['column_name']?.toString() ?? '';
        final value = row['value']?.toString() ?? '';
        editableData[columnName] = value;
      }

      return editableData;
    } catch (e) {
      print('Error getting editable data: $e');
      return {};
    }
  }

  Future<void> transferEmployeeToTransferred({
    required String badgeNo,
    required Map<String, dynamic> transferData,
  }) async {
    try {
      // Check if transferred table exists with correct schema
      try {
        await db.rawQuery('SELECT S_NO FROM transferred LIMIT 1');
        // Table exists with S_NO column, so schema is correct
      } catch (e) {
        // Table doesn't exist or has wrong schema, recreate it
        await db.execute('DROP TABLE IF EXISTS transferred');

        // Create transferred table with all necessary columns
        await db.execute('''
          CREATE TABLE transferred (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            S_NO TEXT,
            Badge_NO TEXT NOT NULL UNIQUE,
            Position_Code TEXT,
            Employee_Name TEXT,
            Bus_Line TEXT,
            Depart_Text TEXT,
            Grade TEXT,
            Grade_Range TEXT,
            Emp_Position_Code TEXT,
            Position_Text TEXT,
            New_Bus_Line TEXT,
            Dept TEXT,
            Position_Abbreviation TEXT,
            Position_Description TEXT,
            OrgUnit_Description TEXT,
            Grade_Range6 TEXT,
            Occupancy TEXT,
            Badge_Number TEXT,
            Grade_GAP TEXT,
            POD TEXT,
            ERD TEXT,
            Transfer_Type TEXT,
            DONE_YES_NO TEXT,
            Available_in_ERD TEXT,
            POD_Remarks TEXT,
            ERD_Remarks TEXT,
            created_date TEXT,
            transfer_date TEXT
          )
        ''');
      }

      // Get editable data for this employee
      final editableData = await getEditableData(
        badgeNo: badgeNo,
        screenType: 'transfers',
      );

      // Prepare data for insertion
      final dataToInsert = Map<String, dynamic>.from(transferData);
      dataToInsert['transfer_date'] = DateTime.now().toIso8601String();

      // Add editable data
      if (editableData.containsKey('ERD_Remarks')) {
        dataToInsert['ERD_Remarks'] = editableData['ERD_Remarks'];
      }
      if (editableData.containsKey('POD_Remarks')) {
        dataToInsert['POD_Remarks'] = editableData['POD_Remarks'];
      }
      if (editableData.containsKey('Available_in_ERD')) {
        dataToInsert['Available_in_ERD'] = editableData['Available_in_ERD'];
      }

      // Insert into transferred table
      await db.insert('transferred', dataToInsert,
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Clear the editable data for this employee from transfers screen
      await _clearEditableDataForEmployee(badgeNo, 'transfers');

      print('Employee transferred successfully: $badgeNo');
    } catch (e) {
      print('Error transferring employee: $e');
      throw Exception('Failed to transfer employee: $e');
    }
  }

  // Helper method to clear editable data for a specific employee and screen
  Future<void> _clearEditableDataForEmployee(
      String badgeNo, String screenType) async {
    try {
      await db.delete(
        _tableName,
        where: 'badge_no = ? AND screen_type = ?',
        whereArgs: [badgeNo, screenType],
      );
      print(
          'Cleared editable data for employee $badgeNo on screen $screenType');
    } catch (e) {
      print('Error clearing editable data: $e');
    }
  }

  // Public method to clear editable data for a specific employee and screen
  Future<void> clearEditableDataForEmployee(
      String badgeNo, String screenType) async {
    await _clearEditableDataForEmployee(badgeNo, screenType);
  }

  // Public method to clear all editable data for a specific employee (all screens)
  Future<void> clearAllEditableDataForEmployee(String badgeNo) async {
    try {
      await db.delete(
        _tableName,
        where: 'badge_no = ?',
        whereArgs: [badgeNo],
      );
      print('Cleared all editable data for employee $badgeNo');
    } catch (e) {
      print('Error clearing all editable data: $e');
    }
  }
}
