import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TableDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Map<String, String> _arabicColumnNames;
  final Function(Map<String, dynamic>)? onDeleteRecord;
  final VoidCallback? onNeedMoreData;
  final Set<String> _clipboardValues = <String>{};
  final Function(String)? onCellSelected;
  final Function(String)? onCopyCellContent;

  TableDataSource(
    this._data,
    this._columns,
    this._arabicColumnNames, {
    this.onDeleteRecord,
    this.onNeedMoreData,
    this.onCellSelected,
    this.onCopyCellContent,
  }) {
    _dataGridRows =
        _data.map<DataGridRow>((dataRow) {
          // Create mutable copy to avoid read-only issues
          final mutableRow = Map<String, dynamic>.from(dataRow);

          return DataGridRow(
            cells:
                _columns.map<DataGridCell>((column) {
                  // Special handling for upload_date column
                  if (column == 'upload_date') {
                    final value = mutableRow[column]?.toString() ?? '';
                    if (value.isNotEmpty) {
                      try {
                        final dateTime = DateTime.parse(value);
                        return DataGridCell<String>(
                          columnName: column,
                          value:
                              '${dateTime.toLocal().toString().split('.')[0]}',
                        );
                      } catch (e) {
                        return DataGridCell<String>(
                          columnName: column,
                          value: value,
                        );
                      }
                    }
                    return DataGridCell<String>(
                      columnName: column,
                      value: 'غير متوفر',
                    );
                  }
                  return DataGridCell<String>(
                    columnName: column,
                    value: mutableRow[column]?.toString() ?? '',
                  );
                }).toList(),
          );
        }).toList();
  }

  List<DataGridRow> _dataGridRows = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  void clearSelection() {
    _clipboardValues.clear();
  }

  String getSelectedCellsAsText() {
    return _clipboardValues.join('\n');
  }

  // Add public getter for clipboard values count
  int get clipboardValuesCount => _clipboardValues.length;

  // Add public method to add to clipboard
  void addToClipboard(String value) {
    _clipboardValues.add(value);
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = rows.indexOf(row);

    // Add safety check for valid data
    if (rowIndex < 0 || rowIndex >= _data.length) {
      // Return empty row adapter if data is out of bounds
      return DataGridRowAdapter(
        color: Colors.white,
        cells: List.generate(_columns.length + 1, (index) => Container()),
      );
    }

    final record = _data[rowIndex];

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          // Check if this specific cell should be highlighted
          final isHighlighted =
              _data[rowIndex].containsKey(
                '${dataGridCell.columnName}_highlighted',
              ) &&
              _data[rowIndex]['${dataGridCell.columnName}_highlighted'] == true;

          return GestureDetector(
            onSecondaryTap: () {
              // Right click: add this cell value to clipboard collection
              final cellValue = dataGridCell.value.toString();
              _clipboardValues.add(cellValue);
              final allValues = _clipboardValues.join('\n');
              Clipboard.setData(ClipboardData(text: allValues));
              onCopyCellContent?.call(
                'تم إضافة إلى الحافظة (${_clipboardValues.length} عنصر)',
              );
            },
            onDoubleTap: () {
              // Double click: clear clipboard and copy only this cell
              _clipboardValues.clear();
              final cellValue = dataGridCell.value.toString();
              Clipboard.setData(ClipboardData(text: cellValue));
              onCopyCellContent?.call('تم نسخ: $cellValue');
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color:
                    isHighlighted
                        ? Colors.yellow.withOpacity(0.5)
                        : Colors.transparent,
              ),
              child: Text(
                dataGridCell.value.toString(),
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList();

    // Add delete button for actions column - only if we have columns
    if (_columns.isNotEmpty) {
      cells.add(
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onDeleteRecord?.call(record),
            tooltip: 'حذف السجل',
          ),
        ),
      );
    }

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }
}
