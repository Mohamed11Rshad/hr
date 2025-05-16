import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TableDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Map<String, String> _arabicColumnNames;
  final Function(Map<String, dynamic>)? onDeleteRecord;
  final VoidCallback? onNeedMoreData;

  TableDataSource(
    this._data,
    this._columns,
    this._arabicColumnNames, {
    this.onDeleteRecord,
    this.onNeedMoreData,
  }) {
    _dataGridRows = _data.map<DataGridRow>((dataRow) {
      return DataGridRow(
        cells: _columns.map<DataGridCell>((column) {
          // Special handling for upload_date column
          if (column == 'upload_date') {
            final value = dataRow[column]?.toString() ?? '';
            if (value.isNotEmpty) {
              try {
                final dateTime = DateTime.parse(value);
                return DataGridCell<String>(
                  columnName: column,
                  value: '${dateTime.toLocal().toString().split('.')[0]}',
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
            value: dataRow[column]?.toString() ?? '',
          );
        }).toList(),
      );
    }).toList();
  }

  List<DataGridRow> _dataGridRows = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = rows.indexOf(row);
    final record = _data[rowIndex];

    final cells = row.getCells().map<Widget>((dataGridCell) {
      // Check if this specific cell should be highlighted
      final isHighlighted = _data[rowIndex].containsKey(
            '${dataGridCell.columnName}_highlighted',
          ) &&
          _data[rowIndex]['${dataGridCell.columnName}_highlighted'] == true;

      // Skip rendering the metadata columns used for highlighting
      if (dataGridCell.columnName.endsWith('_highlighted')) {
        return Container();
      }

      if (dataGridCell.columnName == 'upload_date') {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            dataGridCell.value.toString(),
            style: TextStyle(
              color: dataGridCell.value == 'غير متوفر'
                  ? Colors.red.shade300
                  : Colors.blue.shade800,
              fontSize: 13,
              fontWeight: dataGridCell.value != 'غير متوفر'
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }

      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        decoration: isHighlighted
            ? BoxDecoration(
                color: Colors.yellow.shade200,
                border: Border.all(
                  color: Colors.orange.shade300,
                  width: 1,
                ),
              )
            : null,
        child: Text(
          dataGridCell.value.toString(),
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();

    // Add delete button at the end
    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: onDeleteRecord != null ? () => onDeleteRecord!(record) : null,
          tooltip: 'حذف',
        ),
      ),
    );

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }

  @override
  int compare(DataGridRow? a, DataGridRow? b, SortColumnDetails sortColumn) {
    if (a == null || b == null) {
      return 0;
    }

    final String? valueA = a
        .getCells()
        .firstWhere((cell) => cell.columnName == sortColumn.name)
        .value;
    final String? valueB = b
        .getCells()
        .firstWhere((cell) => cell.columnName == sortColumn.name)
        .value;

    return sortColumn.sortDirection == DataGridSortDirection.ascending
        ? valueA?.compareTo(valueB ?? '') ?? 0
        : valueB?.compareTo(valueA ?? '') ?? 0;
  }
}