import 'package:flutter/material.dart';
import 'package:hr/widgets/editable_data_grid.dart' hide TextButton;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class EditableTableDialog extends StatefulWidget {
  final Database db;
  final String tableName;

  const EditableTableDialog({
    Key? key,
    required this.db,
    required this.tableName,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context,
    Database db,
    String tableName,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditableTableDialog(db: db, tableName: tableName),
    );
  }

  @override
  State<EditableTableDialog> createState() => _EditableTableDialogState();
}

class _EditableTableDialogState extends State<EditableTableDialog> {
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  Future<void> _loadTableData() async {
    try {
      final data = await widget.db.query(widget.tableName);

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
    try {
      final record = _tableData[rowIndex];
      final id = record['id'];

      await widget.db.update(
        widget.tableName,
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

  Future<void> _deleteRow(int rowIndex) async {
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

      await widget.db.delete(
        widget.tableName,
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
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'تعديل جدول: ${widget.tableName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
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
    );
  }
}
