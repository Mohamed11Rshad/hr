import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TerminatedDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Function(Map<String, dynamic>)? onRemoveTerminated;
  final Function(String)? onCopyCellContent;
  final Function(String, String, String)? onUpdateDateField;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  TerminatedDataSource(
    this._data,
    this._columns, {
    this.onRemoveTerminated,
    this.onCopyCellContent,
    this.onUpdateDateField,
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

  void refreshData() {
    _buildDataGridRows();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    if (rowIndex < 0 || rowIndex >= _data.length) {
      final emptyCells = List.generate(
        _columns.length + 1,
        (index) => Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: const Text(''),
        ),
      );
      return DataGridRowAdapter(cells: emptyCells);
    }

    final record = _data[rowIndex];

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          Widget cellWidget;

          // Check if this is an editable date field (F5, F7, F8)
          if (['F5', 'F7', 'F8'].contains(dataGridCell.columnName) &&
              onUpdateDateField != null) {
            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap:
                    () => _showDateEditor(
                      record,
                      dataGridCell.columnName,
                      dataGridCell.value.toString(),
                    ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.green.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_calendar,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dataGridCell.value.toString().isNotEmpty
                              ? dataGridCell.value.toString()
                              : 'Click to set date',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                dataGridCell.value.toString().isNotEmpty
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontStyle:
                                dataGridCell.value.toString().isNotEmpty
                                    ? FontStyle.normal
                                    : FontStyle.italic,
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
            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _formatCellValue(
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

          return GestureDetector(
            onSecondaryTap: () {
              final cellValue = dataGridCell.value.toString();
              _clipboardValues.add(cellValue);
              final allValues = _clipboardValues.join('\n');
              Clipboard.setData(ClipboardData(text: allValues));
              onCopyCellContent?.call(
                'تم إضافة إلى الحافظة (${_clipboardValues.length} عنصر)',
              );
            },
            onDoubleTap: () {
              _clipboardValues.clear();
              final cellValue = dataGridCell.value.toString();
              Clipboard.setData(ClipboardData(text: cellValue));
              onCopyCellContent?.call('تم نسخ: $cellValue');
            },
            child: cellWidget,
          );
        }).toList();

    // Add delete button
    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => onRemoveTerminated?.call(record),
          tooltip: 'حذف المسرح',
        ),
      ),
    );

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.green.shade50,
      cells: cells,
    );
  }

  void _showDateEditor(
    Map<String, dynamic> record,
    String fieldName,
    String currentValue,
  ) async {
    final sNo = record['S_NO']?.toString() ?? '';
    if (sNo.isEmpty || onUpdateDateField == null) return;

    onUpdateDateField!(sNo, fieldName, currentValue);
  }

  String _formatCellValue(String columnName, String value) {
    // Format all numeric values as integers (no decimals)
    if (columnName == 'Old_Basic' ||
        columnName == 'Adjustment' ||
        columnName == 'Old_Basic_Plus_Adj' ||
        columnName == 'Annual_Increment' ||
        columnName == 'New_Basic' ||
        columnName == 'Appraisal_Amount') {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.round().toString();
      }
    }

    // Format decimal values for lump sum calculations
    if (columnName == 'Current_Lump_Sum' ||
        columnName == 'Amount_Div_12' ||
        columnName == 'New_Lump_Sum') {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.toStringAsFixed(2);
      }
    }

    // Format precise decimal values
    if (columnName == 'Amount_Div_12_Per_Month') {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.toStringAsFixed(4);
      }
    }

    // Format integer values for counts
    if (columnName == 'No_of_Months' || columnName == 'No_of_Days') {
      final intValue = int.tryParse(value);
      if (intValue != null) {
        return intValue.toString();
      }
    }

    return value;
  }
}
