import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TerminatedDataService {
  final Database db;
  final String baseTableName;

  TerminatedDataService({required this.db, required this.baseTableName});

  Future<void> initializeTerminatedTable() async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS terminated (
          S_NO INTEGER PRIMARY KEY AUTOINCREMENT,
          Badge_NO TEXT NOT NULL,
          Employee_Name TEXT,
          Grade TEXT,
          Termination_Date TEXT,
          Old_Basic TEXT,
          Adjust_Months TEXT,
          Adjustment TEXT,
          Old_Basic_Plus_Adj TEXT,
          Adjust_Date TEXT,
          Appraisal_Text TEXT,
          Annual_Increment TEXT,
          Appraisal_NO_of_Months TEXT,
          Appraisal_Amount TEXT,
          Appraisal_Date TEXT,
          New_Basic TEXT,
          Current_Lump_Sum TEXT,
          Amount_Div_12 TEXT,
          Amount_Div_12_Per_Month TEXT,
          No_of_Months TEXT,
          No_of_Days TEXT,
          New_Lump_Sum TEXT,
          F5 TEXT DEFAULT '',
          F7 TEXT DEFAULT '',
          F8 TEXT DEFAULT '',
          Action_Date TEXT,
          created_date TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('Error creating terminated table: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> transferFromTermination(
    Map<String, dynamic> terminationRecord,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Create terminated record with all termination data
      final terminatedRecord = Map<String, dynamic>.from(terminationRecord);
      terminatedRecord.remove('S_NO'); // Remove to let auto-increment work
      terminatedRecord['F5'] = '';
      terminatedRecord['F7'] = '';
      terminatedRecord['F8'] = '';
      terminatedRecord['Action_Date'] = _formatDate(DateTime.now());
      terminatedRecord['created_date'] = now;

      // Insert into terminated table
      await db.insert('terminated', terminatedRecord);

      // Remove from terminations table
      await db.delete(
        'terminations',
        where: 'S_NO = ?',
        whereArgs: [terminationRecord['S_NO']],
      );

      return {
        'success': true,
        'message': 'تم نقل السجل إلى قائمة المسرحين بنجاح',
      };
    } catch (e) {
      print('Error transferring to terminated: $e');
      return {'success': false, 'message': 'خطأ في نقل السجل: ${e.toString()}'};
    }
  }

  Future<List<Map<String, dynamic>>> getTerminatedData() async {
    try {
      final terminated = await db.query(
        'terminated',
        orderBy: 'CAST(Badge_NO AS INTEGER) ASC',
      );

      return terminated;
    } catch (e) {
      print('Error getting terminated data: $e');
      rethrow;
    }
  }

  Future<void> updateDateField(
    String sNo,
    String fieldName,
    String dateValue,
  ) async {
    try {
      if (!['F5', 'F7', 'F8'].contains(fieldName)) {
        throw ArgumentError('Invalid field name: $fieldName');
      }

      await db.update(
        'terminated',
        {fieldName: dateValue},
        where: 'S_NO = ?',
        whereArgs: [sNo],
      );
    } catch (e) {
      print('Error updating date field: $e');
      rethrow;
    }
  }

  Future<void> removeTerminated(String sNo) async {
    try {
      await db.delete('terminated', where: 'S_NO = ?', whereArgs: [sNo]);
    } catch (e) {
      print('Error removing terminated: $e');
      rethrow;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
