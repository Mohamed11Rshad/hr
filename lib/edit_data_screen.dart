import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/services/database_service.dart';
import 'package:hr/widgets/editable_data_grid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
      final allTables = await DatabaseService.getAvailableTables(widget.db!);

      // Exclude base sheets and internal application tables from editing
      final internalTables = {'promoted_employees', 'promotions', 'transfers'};

      final editableTables =
          allTables
              .where(
                (table) =>
                    !table.toLowerCase().contains('base') &&
                    table != 'Base_Sheet' &&
                    !internalTables.contains(table),
              )
              .toList();

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
      final data = await widget.db!.query(tableName);

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

  Future<void> _updateCellValue(
    int rowIndex,
    String columnName,
    String newValue,
  ) async {
    if (widget.db == null || _selectedTable == null) return;

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التحديث: ${e.toString()}')),
      );
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة سجل جديد')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إضافة السجل: ${e.toString()}')),
      );
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف السجل بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: ${e.toString()}')));
    }
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
      data: _tableData,
      columns: _columns,
      onCellUpdate: _updateCellValue,
      onDeleteRow: _deleteRow,
    );
  }
}
