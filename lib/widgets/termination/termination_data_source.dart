import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hr/core/app_colors.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TerminationDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Function(Map<String, dynamic>)? onRemoveTermination;
  final Function(String)? onCopyCellContent;
  final Function(String, String)? onUpdateAppraisalText;
  final Function(Map<String, dynamic>)? onTransferToTerminated; // Add this
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  TerminationDataSource(
    this._data,
    this._columns, {
    this.onRemoveTermination,
    this.onCopyCellContent,
    this.onUpdateAppraisalText,
    this.onTransferToTerminated, // Add this
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
                  // For Transfer_Action column, just provide empty value
                  if (column == 'Transfer_Action') {
                    return DataGridCell<String>(columnName: column, value: '');
                  }
                  return DataGridCell<String>(
                    columnName: column,
                    value: dataRow[column]?.toString() ?? '',
                  );
                }).toList(),
          );
        }).toList();
  }

  // Add method to refresh data when the underlying data changes
  void refreshData() {
    _buildDataGridRows();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    // Safety check to prevent RangeError
    if (rowIndex < 0 || rowIndex >= _data.length) {
      // Return a row adapter with empty cells matching the column count
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

          // Check if this is the Transfer_Action column
          if (dataGridCell.columnName == 'Transfer_Action') {
            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4.0),
              child: ElevatedButton.icon(
                onPressed: () => onTransferToTerminated?.call(record),
                icon: const Icon(Icons.transfer_within_a_station, size: 16),
                label: const Text('Terminate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(80, 32),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }
          // Check if this is the Appraisal_Text column - make it editable
          else if (dataGridCell.columnName == 'Appraisal_Text' &&
              onUpdateAppraisalText != null) {
            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap:
                    () => _showAppraisalTextEditor(
                      record,
                      dataGridCell.value.toString(),
                    ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.blue.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dataGridCell.value.toString().isNotEmpty
                              ? dataGridCell.value.toString()
                              : 'Click to edit',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                dataGridCell.value.toString().isNotEmpty
                                    ? Colors.blue.shade700
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
          onPressed: () => onRemoveTermination?.call(record),
          tooltip: 'حذف التسريح',
        ),
      ),
    );

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }

  void _showAppraisalTextEditor(
    Map<String, dynamic> record,
    String currentValue,
  ) async {
    final sNo = record['S_NO']?.toString() ?? '';
    if (sNo.isEmpty || onUpdateAppraisalText == null) return;

    onUpdateAppraisalText!(sNo, currentValue);
  }

  String _formatCellValue(String columnName, String value) {
    // Format all numeric values as integers (no decimals)
    if (columnName == 'Old_Basic' ||
        columnName == 'Old_Basic_Plus_Adj' ||
        columnName == 'Annual_Increment' ||
        columnName == 'New_Basic' ||
        columnName == 'Appraisal_Amount') {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.round().toString();
      }
    }

    // Format decimal values for adjustment months and adjustment (allow decimal places)
    if (columnName == 'Adjust_Months' || columnName == 'Adjustment') {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.toStringAsFixed(2);
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
