import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class AppraisalDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Function(String)? onCopyCellContent;
  final Function(int, String, String)? onCellValueChanged;
  final BuildContext? context;
  late List<DataGridRow> _dataGridRows;
  final List<String> _clipboardValues = [];

  AppraisalDataSource(
    this._data,
    this._columns, {
    this.onCopyCellContent,
    this.onCellValueChanged,
    this.context,
  }) {
    _buildDataGridRows();
  }

  void _buildDataGridRows() {
    _dataGridRows =
        _data.map<DataGridRow>((dataRow) {
          return DataGridRow(
            cells:
                _columns.map<DataGridCell>((column) {
                  final value = dataRow[column];
                  return DataGridCell(columnName: column, value: value ?? '');
                }).toList(),
          );
        }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  Widget _buildCell(DataGridCell dataGridCell) {
    // Check if this is an editable column
    if (dataGridCell.columnName == 'New_Basic_System' ||
        dataGridCell.columnName == 'Grade') {
      final isGrade = dataGridCell.columnName == 'Grade';
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap:
              () =>
                  isGrade
                      ? _showGradeEditor(dataGridCell)
                      : _showNewBasicSystemEditor(dataGridCell),
          onSecondaryTap: () => _handleRightClick(dataGridCell),
          child: Container(
            width: double.infinity,
            height: 40.h,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(6),
              color: Colors.green.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dataGridCell.value.toString().isNotEmpty
                        ? dataGridCell.value.toString()
                        : 'اضغط للتعديل',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          dataGridCell.value.toString().isNotEmpty
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Regular cell
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => _handleDoubleClick(dataGridCell),
          onSecondaryTap: () => _handleRightClick(dataGridCell),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: Text(
              dataGridCell.value.toString(),
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  void _handleRightClick(DataGridCell dataGridCell) {
    final cellValue = dataGridCell.value.toString();
    _clipboardValues.add(cellValue);
    final allValues = _clipboardValues.join('\n');
    Clipboard.setData(ClipboardData(text: allValues));
    onCopyCellContent?.call(
      'تم إضافة إلى الحافظة (${_clipboardValues.length} عنصر)',
    );
  }

  void _handleDoubleClick(DataGridCell dataGridCell) {
    _clipboardValues.clear();
    final cellValue = dataGridCell.value.toString();
    Clipboard.setData(ClipboardData(text: cellValue));
    onCopyCellContent?.call('تم نسخ: $cellValue');
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    // Safety check to prevent RangeError
    if (rowIndex < 0 || rowIndex >= _data.length) {
      return DataGridRowAdapter(
        color: Colors.white,
        cells: _columns.map<Widget>((column) => Container()).toList(),
      );
    }

    // Only build cells for visible columns (matching the _columns list)
    final cells =
        _columns.map<Widget>((column) {
          // Find the corresponding cell in the row
          final dataGridCell = row.getCells().firstWhere(
            (cell) => cell.columnName == column,
            orElse: () => DataGridCell(columnName: column, value: ''),
          );
          return _buildCell(dataGridCell);
        }).toList();

    // Determine row color - alternating with subtle colors
    Color rowColor;
    if (rowIndex % 2 == 0) {
      rowColor = Colors.white;
    } else {
      rowColor = Colors.blue.shade50;
    }

    return DataGridRowAdapter(color: rowColor, cells: cells);
  }

  void _showGradeEditor(DataGridCell dataGridCell) async {
    final rowIndex = _dataGridRows.indexWhere(
      (row) => row.getCells().any((cell) => cell == dataGridCell),
    );

    if (rowIndex == -1 || rowIndex >= _data.length) return;

    final record = _data[rowIndex];
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final currentValue = dataGridCell.value.toString();

    if (badgeNo.isEmpty) return;
    if (context == null) return;

    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context!,
      builder:
          (context) => AlertDialog(
            title: const Text('تعديل Grade'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموظف: $badgeNo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Grade',
                    border: OutlineInputBorder(),
                    hintText: 'أدخل Grade...',
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      _data[rowIndex]['Grade'] = result;
      _buildDataGridRows();
      onCellValueChanged?.call(rowIndex, 'Grade', result);
      notifyListeners();
    }
  }

  void _showNewBasicSystemEditor(DataGridCell dataGridCell) async {
    final rowIndex = _dataGridRows.indexWhere(
      (row) => row.getCells().any((cell) => cell == dataGridCell),
    );

    if (rowIndex == -1 || rowIndex >= _data.length) return;

    final record = _data[rowIndex];
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final currentValue = dataGridCell.value.toString();

    if (badgeNo.isEmpty) return;
    if (context == null) return;

    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context!,
      builder:
          (context) => AlertDialog(
            title: const Text('تعديل New Basic System'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموظف: $badgeNo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'New Basic System',
                    border: OutlineInputBorder(),
                    hintText: 'أدخل القيمة ...',
                  ),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      _data[rowIndex]['New_Basic_System'] = result;
      _buildDataGridRows();
      onCellValueChanged?.call(rowIndex, 'New_Basic_System', result);
      notifyListeners();
    }
  }
}
