import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TransfersDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final BuildContext context;
  final Function(Map<String, dynamic>)? onRemoveTransfer;
  final Function(String, String, String)? onUpdateField;
  final Function(String)? onCopyCellContent;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  TransfersDataSource(
    this._data,
    this._columns, {
    required this.context,
    this.onRemoveTransfer,
    this.onUpdateField,
    this.onCopyCellContent,
  }) {
    _buildDataGridRows();
  }

  void clearSelection() {
    _clipboardValues.clear();
  }

  String getSelectedCellsAsText() {
    return _clipboardValues.join('\n');
  }

  int get clipboardValuesCount => _clipboardValues.length;

  void addToClipboard(String value) {
    _clipboardValues.add(value);
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
  List<DataGridRow> get rows => _dataGridRows;

  bool _isFieldEditable(String columnName) {
    const editableFields = {'POD', 'ERD', 'Available_in_ERD'};
    return editableFields.contains(columnName);
  }

  bool _isDropdownField(String columnName) {
    return columnName == 'DONE_YES_NO';
  }

  String _normalizeDropdownValue(String value) {
    // Normalize Arabic values to English for consistency
    switch (value.toLowerCase().trim()) {
      case 'تم':
      case 'done':
        return 'Done';
      case 'نعم':
      case 'yes':
        return 'Yes';
      case 'لا':
      case 'no':
        return 'No';
      case 'إلغاء':
      case 'cancel':
        return 'Cancel';
      default:
        return value.isEmpty ? '' : value;
    }
  }

  Widget _buildRegularCell(DataGridCell dataGridCell) {
    // Convert Arabic values to English for display
    final displayValue =
        dataGridCell.columnName == 'DONE_YES_NO'
            ? _normalizeDropdownValue(dataGridCell.value.toString())
            : dataGridCell.value.toString();

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        displayValue,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEditableCell(
    Map<String, dynamic> record,
    DataGridCell dataGridCell,
  ) {
    // Check if this is the dropdown field
    if (_isDropdownField(dataGridCell.columnName)) {
      return _buildDropdownCell(record, dataGridCell);
    }

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
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل $fieldName'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: fieldName,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
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

    if (result != null && onUpdateField != null) {
      final sNo = record['S_NO']?.toString() ?? '';
      onUpdateField!(sNo, fieldName, result);
    }
  }

  Widget _buildDropdownCell(
    Map<String, dynamic> record,
    DataGridCell dataGridCell,
  ) {
    final currentValue = dataGridCell.value.toString();
    final normalizedValue = _normalizeDropdownValue(currentValue);

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(4),
          color: Colors.green.shade50,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: normalizedValue.isEmpty ? null : normalizedValue,
            hint: const Text(
              'Select',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Done', child: Text('Done')),
              DropdownMenuItem(value: 'Yes', child: Text('Yes')),
              DropdownMenuItem(value: 'No', child: Text('No')),
              DropdownMenuItem(value: 'Cancel', child: Text('Cancel')),
            ],
            onChanged: (String? newValue) {
              if (newValue != null && onUpdateField != null) {
                final sNo = record['S_NO']?.toString() ?? '';

                switch (newValue) {
                  case 'Done':
                    onUpdateField!(sNo, dataGridCell.columnName, newValue);
                    break;
                  case 'No':
                    onRemoveTransfer?.call(record);
                    break;
                  case 'Yes':
                    onUpdateField!(sNo, dataGridCell.columnName, newValue);
                    break;
                  case 'Cancel':
                    break;
                }
              }
            },
            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            dropdownColor: Colors.green.shade50,
          ),
        ),
      ),
    );
  }

  // Add method to refresh data source
  void refreshDataSource() {
    _buildDataGridRows();
    notifyListeners();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    // Safety check to prevent RangeError
    if (rowIndex < 0 || rowIndex >= _data.length) {
      // Return an empty row if index is out of bounds
      return DataGridRowAdapter(
        cells:
            _columns.map<Widget>((column) => Container()).toList()
              ..add(Container()),
      );
    }

    final record = _data[rowIndex];

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              dataGridCell.value.toString(),
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          );
        }).toList();

    // Add delete button
    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => onRemoveTransfer?.call(record),
          tooltip: 'حذف التنقل',
        ),
      ),
    );

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }
}
