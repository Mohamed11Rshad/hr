import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/services/database_service.dart';
import 'package:hr/widgets/editable_data_grid.dart'
    hide SizedBox, ElevatedButton, TextButton;
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

class EditDataScreen extends StatefulWidget {
  final Database? db;

  const EditDataScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<EditDataScreen> createState() => _EditDataScreenState();
}

class _EditDataScreenState extends State<EditDataScreen> {
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    if (widget.db == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Database not initialized';
      });
      return;
    }

    try {
      final allTables = await DatabaseService.getAvailableTables(
        widget.db!,
      ); // Exclude only internal application tables from editing (allow Base_Sheet)
      final internalTables = {'promoted_employees', 'promotions', 'transfers'};

      final editableTables =
          allTables.where((table) => !internalTables.contains(table)).toList();

      setState(() {
        _tables = editableTables;
        _isLoading = false;
        if (_tables.isNotEmpty) {
          _selectedTable = _tables.first;
          _loadTableData(_selectedTable!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading tables: ${e.toString()}';
      });
    }
  }

  Future<void> _loadTableData(String tableName) async {
    setState(() {
      _isLoading = true;
      _tableData = [];
      _columns = [];
    });

    try {
      List<Map<String, dynamic>> data;

      // Special handling for Base_Sheet to show only latest records per employee
      if (tableName == 'Base_Sheet') {
        data = await _getLatestRecordsFromBaseSheet();
      } else {
        // For other tables, load all data normally
        data = await widget.db!.query(tableName);
      }

      if (data.isNotEmpty) {
        _columns = data.first.keys.where((col) => col != 'id').toList();
        _tableData = data.map((row) => Map<String, dynamic>.from(row)).toList();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading table data: ${e.toString()}';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getLatestRecordsFromBaseSheet() async {
    try {
      // First determine the badge column name for ordering
      String badgeColumnName = '';
      try {
        final tableInfo = await widget.db!.rawQuery(
          'PRAGMA table_info("Base_Sheet")',
        );
        badgeColumnName = tableInfo
            .map((col) => col['name'].toString())
            .firstWhere(
              (name) => name.toLowerCase().contains('badge'),
              orElse: () => 'Badge_NO',
            );
      } catch (e) {
        badgeColumnName = 'Badge_NO'; // Default if we can't determine
      }

      final orderBy =
          badgeColumnName.isNotEmpty
              ? 'CAST(t1."$badgeColumnName" AS INTEGER) ASC'
              : 't1.id ASC';

      // Get the latest upload_date
      final latestDateQuery = await widget.db!.rawQuery(
        'SELECT MAX(upload_date) as latest_date FROM "Base_Sheet" WHERE upload_date IS NOT NULL',
      );

      final latestDate = latestDateQuery.first['latest_date']?.toString();

      if (latestDate == null || latestDate.isEmpty) {
        // If no upload_date found, get latest record per badge number
        final data = await widget.db!.rawQuery('''
          SELECT t1.* FROM "Base_Sheet" t1
          INNER JOIN (
            SELECT t2."$badgeColumnName", MAX(t2.id) as max_id
            FROM "Base_Sheet" t2
            GROUP BY t2."$badgeColumnName"
          ) t3 ON t1."$badgeColumnName" = t3."$badgeColumnName" AND t1.id = t3.max_id
          ORDER BY $orderBy
        ''');
        return data;
      }

      // Get records with the latest upload_date, ensuring we get the latest record per badge number
      final data = await widget.db!.rawQuery(
        '''
        SELECT t1.* FROM "Base_Sheet" t1
        INNER JOIN (
          SELECT t2."$badgeColumnName", MAX(t2.id) as max_id
          FROM "Base_Sheet" t2
          WHERE t2.upload_date = ?
          GROUP BY t2."$badgeColumnName"
        ) t3 ON t1."$badgeColumnName" = t3."$badgeColumnName" AND t1.id = t3.max_id
        ORDER BY $orderBy
      ''',
        [latestDate],
      );

      return data;
    } catch (e) {
      print('Error getting latest records from Base_Sheet: $e');
      // Fallback to regular query with latest record per badge
      try {
        final tableInfo = await widget.db!.rawQuery(
          'PRAGMA table_info("Base_Sheet")',
        );
        final badgeColumnName = tableInfo
            .map((col) => col['name'].toString())
            .firstWhere(
              (name) => name.toLowerCase().contains('badge'),
              orElse: () => 'Badge_NO',
            );

        final orderBy =
            badgeColumnName.isNotEmpty
                ? 'CAST(t1."$badgeColumnName" AS INTEGER) ASC'
                : 't1.id ASC';

        return await widget.db!.rawQuery('''
          SELECT t1.* FROM "Base_Sheet" t1
          INNER JOIN (
            SELECT t2."$badgeColumnName", MAX(t2.id) as max_id
            FROM "Base_Sheet" t2
            GROUP BY t2."$badgeColumnName"
          ) t3 ON t1."$badgeColumnName" = t3."$badgeColumnName" AND t1.id = t3.max_id
          ORDER BY $orderBy
        ''');
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        return await widget.db!.query('Base_Sheet');
      }
    }
  }

  Future<void> _updateCellValue(
    int rowIndex,
    String columnName,
    String newValue,
  ) async {
    if (widget.db == null || _selectedTable == null) return;

    // Check if this is a non-editable column in Base_Sheet
    if (_selectedTable == 'Base_Sheet') {
      if (columnName == 'Badge_NO' || columnName == 'Employee_Name') {
        CustomSnackbar.showError(
          context,
          'لا يمكن تعديل رقم الموظف أو اسم الموظف',
        );
        return;
      }
    }

    try {
      final record = _tableData[rowIndex];
      final id = record['id'];

      await widget.db!.update(
        _selectedTable!,
        {columnName: newValue},
        where: 'id = ?',
        whereArgs: [id],
      );

      setState(() {
        _tableData[rowIndex][columnName] = newValue;
      });

      CustomSnackbar.showSuccess(context, 'تم تحديث البيانات بنجاح');
    } catch (e) {
      CustomSnackbar.showError(context, 'خطأ في التحديث: ${e.toString()}');
    }
  }

  Future<void> _addNewRow() async {
    if (widget.db == null || _selectedTable == null || _columns.isEmpty) return;

    try {
      // Create a new record with empty values
      final newRecord = <String, dynamic>{};
      for (final column in _columns) {
        newRecord[column] = '';
      }

      final id = await widget.db!.insert(_selectedTable!, newRecord);
      newRecord['id'] = id;

      setState(() {
        _tableData.add(newRecord);
      });

      CustomSnackbar.showSuccess(context, 'تم إضافة سجل جديد');
    } catch (e) {
      CustomSnackbar.showError(context, 'خطأ في إضافة السجل: ${e.toString()}');
    }
  }

  Future<void> _deleteRow(int rowIndex) async {
    if (widget.db == null || _selectedTable == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text('هل أنت متأكد من حذف هذا السجل؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final record = _tableData[rowIndex];
      final id = record['id'];

      await widget.db!.delete(
        _selectedTable!,
        where: 'id = ?',
        whereArgs: [id],
      );

      setState(() {
        _tableData.removeAt(rowIndex);
      });

      CustomSnackbar.showSuccess(context, 'تم حذف السجل بنجاح');
    } catch (e) {
      CustomSnackbar.showError(context, 'خطأ في الحذف: ${e.toString()}');
    }
  }

  Future<bool> _isCellEditable(int rowIndex, String columnName) async {
    // For Base_Sheet table, check specific column restrictions
    if (_selectedTable == 'Base_Sheet') {
      // Badge_NO and Employee_Name are never editable in Base_Sheet
      if (columnName == 'Badge_NO' || columnName == 'Employee_Name') {
        return false;
      }

      // Basic column is now always editable - removed promotion check
    }

    // All other cells are editable
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_tables.isEmpty) {
      return const Center(child: Text('لا توجد جداول قابلة للتعديل'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Table selector
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: _selectedTable,
            decoration: const InputDecoration(
              labelText: 'اختر الجدول للتعديل',
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryColor),
              ),
              border: OutlineInputBorder(),
            ),
            items:
                _tables.map((table) {
                  return DropdownMenuItem(value: table, child: Text(table));
                }).toList(),
            onChanged: (value) {
              if (value != null && value != _selectedTable) {
                setState(() {
                  _selectedTable = value;
                });
                _loadTableData(value);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        // Add new row button
        ElevatedButton.icon(
          onPressed: _addNewRow,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة سجل', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_tableData.isEmpty) {
      return const Center(child: Text('لا توجد بيانات في هذا الجدول'));
    }

    return EditableDataGrid(
      key: ValueKey(_tableData.length), // Add key to force refresh
      data: _tableData,
      columns: _columns,
      onCellUpdate: _updateCellValue,
      onDeleteRow: _deleteRow,
      selectedTable: _selectedTable,
      checkCellEditable: _isCellEditable,
    );
  }
}
