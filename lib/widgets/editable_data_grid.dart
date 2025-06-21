import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class EditableDataGrid extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Function(int, String, String) onCellUpdate;
  final Function(int) onDeleteRow;
  final String? selectedTable;
  final Function(int, String)? checkCellEditable;

  const EditableDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.onCellUpdate,
    required this.onDeleteRow,
    this.selectedTable,
    this.checkCellEditable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataSource = _EditableDataSource(
      data,
      columns,
      context: context,
      onCellUpdate: onCellUpdate,
      onDeleteRow: onDeleteRow,
      selectedTable: selectedTable,
      checkCellEditable: checkCellEditable,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SfDataGridTheme(
        data: SfDataGridThemeData(
          headerColor: AppColors.primaryColor,
          gridLineColor: Colors.grey.shade300,
          gridLineStrokeWidth: 1.0,
          selectionColor: Colors.blue.shade100,
          filterIconColor: Colors.white,
          sortIconColor: Colors.white,
        ),
        child: SfDataGrid(
          source: dataSource,
          columnWidthMode: ColumnWidthMode.fitByColumnName,
          allowSorting: true,
          allowFiltering: true,
          selectionMode: SelectionMode.single,
          showHorizontalScrollbar: true,
          showVerticalScrollbar: true,
          isScrollbarAlwaysShown: true,
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          rowHeight: 60,
          headerRowHeight: 65,
          columns: _buildGridColumns(),
        ),
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    final gridColumns =
        columns.map((column) {
          return GridColumn(
            columnName: column,
            minimumWidth: 220,
            autoFitPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                column,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList();

    // Add delete action column
    gridColumns.add(
      GridColumn(
        columnName: 'actions',
        width: 100,
        allowSorting: false,
        allowFiltering: false,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: const Text(
            'حذف',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );

    return gridColumns;
  }
}

class _EditableDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final BuildContext context;
  final Function(int, String, String) onCellUpdate;
  final Function(int) onDeleteRow;
  final String? selectedTable;
  final Function(int, String)? checkCellEditable;
  List<DataGridRow> _dataGridRows = [];

  _EditableDataSource(
    this._data,
    this._columns, {
    required this.context,
    required this.onCellUpdate,
    required this.onDeleteRow,
    this.selectedTable,
    this.checkCellEditable,
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
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4.0),
            child: FutureBuilder<bool>(
              future: _isCellEditableAsync(rowIndex, dataGridCell.columnName),
              builder: (context, snapshot) {
                final isEditable = snapshot.data ?? true;

                return InkWell(
                  onTap:
                      isEditable
                          ? () => _showEditDialog(
                            rowIndex,
                            dataGridCell.columnName,
                            dataGridCell.value.toString(),
                          )
                          : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isEditable
                                ? AppColors.primaryColor.withAlpha(150)
                                : Colors.grey.shade600,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color:
                          isEditable
                              ? AppColors.primaryColor.withAlpha(50)
                              : Colors.grey.shade300,
                    ),
                    child: Text(
                      dataGridCell.value.toString().isEmpty
                          ? (isEditable ? 'Click to edit' : 'Not editable')
                          : dataGridCell.value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isEditable
                                ? (dataGridCell.value.toString().isEmpty
                                    ? Colors.grey.shade600
                                    : AppColors.primaryColor)
                                : Colors.grey.shade600,
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
                );
              },
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
          onPressed: () => onDeleteRow(rowIndex),
          tooltip: 'حذف السجل',
        ),
      ),
    );

    return DataGridRowAdapter(color: Colors.white, cells: cells);
  }

  Future<bool> _isCellEditableAsync(int rowIndex, String columnName) async {
    // For Base_Sheet table, check specific restrictions
    if (selectedTable == 'Base_Sheet') {
      // Badge_NO and Employee_Name are never editable
      if (columnName == 'Badge_NO' || columnName == 'Employee_Name') {
        return false;
      }

      // Basic column requires database check
      if (columnName == 'Basic' && checkCellEditable != null) {
        try {
          return await checkCellEditable!(rowIndex, columnName);
        } catch (e) {
          return true; // Default to editable if check fails
        }
      }
    }

    // All other cells are editable
    return true;
  }

  bool _isCellEditable(int rowIndex, String columnName) {
    // For Base_Sheet table, check if Basic column is editable
    if (selectedTable == 'Base_Sheet' && columnName == 'Basic') {
      // This is a simplified check - the async version should be used for accurate results
      return true;
    }

    // All other cells are editable
    return true;
  }

  void _showEditDialog(
    int rowIndex,
    String columnName,
    String currentValue,
  ) async {
    // Check if this cell is editable
    if (!_isCellEditable(rowIndex, columnName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الحقل غير قابل للتعديل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final controller = TextEditingController(text: currentValue);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل $columnName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: columnName,
                    border: const OutlineInputBorder(),
                    hintText: 'أدخل القيمة...',
                  ),
                  maxLines: 3,
                  maxLength: 500,
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

    if (result != null) {
      onCellUpdate(rowIndex, columnName, result);
      // Update the local data and refresh the grid
      _data[rowIndex][columnName] = result;
      _buildDataGridRows();
      notifyListeners();
    }
  }
}
