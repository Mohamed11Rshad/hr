import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/constants/transfers_constants.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TransfersDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final BuildContext context;
  final Function(Map<String, dynamic>)? onRemoveTransfer;
  final Function(String)? onCopyCellContent;
  final Function(String, String, String)? onUpdateField;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  TransfersDataSource(
    this._data,
    this._columns, {
    required this.context,
    this.onRemoveTransfer,
    this.onCopyCellContent,
    this.onUpdateField,
  }) {
    _buildDataGridRows();
  }

  void _buildDataGridRows() {
    _dataGridRows =
        _data.map<DataGridRow>((dataRow) {
          return DataGridRow(
            cells:
                _columns.map<DataGridCell>((column) {
                  return DataGridCell<String>(
                    columnName: column,
                    value: dataRow[column]?.toString() ?? '',
                  );
                }).toList(),
          );
        }).toList();
  }

  @override
  List<DataGridRow> get rows => List.from(_dataGridRows);

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);
    final record = _data[rowIndex];

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          final isEditable = TransfersConstants.editableColumns.contains(
            dataGridCell.columnName,
          );

          Widget cellWidget;

          if (isEditable && onUpdateField != null) {
            cellWidget = _buildEditableCell(record, dataGridCell);
          } else {
            cellWidget = _buildRegularCell(dataGridCell);
          }

          return GestureDetector(
            onSecondaryTap: () => _handleRightClick(dataGridCell),
            onDoubleTap: () => _handleDoubleClick(dataGridCell),
            child: cellWidget,
          );
        }).toList();

    // Add delete button
    cells.add(_buildDeleteButton(record));

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }

  Widget _buildEditableCell(
    Map<String, dynamic> record,
    DataGridCell dataGridCell,
  ) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4.0),
      child: InkWell(
        onTap:
            () => _showEditDialog(
              record,
              dataGridCell.columnName,
              dataGridCell.value.toString(),
            ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.blue.shade50,
          ),
          child: Text(
            dataGridCell.value.toString().isEmpty
                ? 'Click to edit'
                : dataGridCell.value.toString(),
            style: TextStyle(
              fontSize: 12.w.clamp(12, 14),
              color:
                  dataGridCell.value.toString().isEmpty
                      ? Colors.grey.shade600
                      : Colors.blue.shade700,
              fontStyle:
                  dataGridCell.value.toString().isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildRegularCell(DataGridCell dataGridCell) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        _formatDisplayValue(
          dataGridCell.columnName,
          dataGridCell.value.toString(),
        ),
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDeleteButton(Map<String, dynamic> record) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4.0),
      child: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
        onPressed:
            onRemoveTransfer != null ? () => onRemoveTransfer!(record) : null,
        tooltip: 'حذف التنقل',
      ),
    );
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

  void _showEditDialog(
    Map<String, dynamic> record,
    String fieldName,
    String currentValue,
  ) async {
    final sNo = record['S_NO']?.toString() ?? '';
    if (sNo.isEmpty || onUpdateField == null) return;

    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل ${_getFieldDisplayName(fieldName)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: _getFieldDisplayName(fieldName),
                    border: const OutlineInputBorder(),
                    hintText: 'أدخل القيمة...',
                  ),
                  maxLines: 2,
                  maxLength: 200,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );

    if (result != null) {
      onUpdateField!(sNo, fieldName, result);
    }
  }

  String _formatDisplayValue(String columnName, String value) {
    // List of numeric columns that should be displayed as integers
    const numericColumns = ['S_NO', 'Badge_NO', 'Grade', 'Badge_Number'];

    if (numericColumns.contains(columnName) && value.isNotEmpty) {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.round().toString();
      }
    }
    return value;
  }

  String _getFieldDisplayName(String fieldName) {
    return TransfersConstants.columnNames[fieldName] ?? fieldName;
  }
}
