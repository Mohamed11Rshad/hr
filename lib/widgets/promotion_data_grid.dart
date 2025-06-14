import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class PromotionDataGrid extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Map<String, String> columnNames;
  final Set<String> hiddenColumns;
  final Function(String) onRemoveEmployee;
  final Function(String) onPromoteEmployee;
  final Function(String) onCopyCellContent;
  final Function(String, String)? onUpdateAdjustedDate;
  final Function(String, String)? onUpdatePromReason;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final Function(String)? onCellSelected;

  const PromotionDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.columnNames,
    required this.hiddenColumns,
    required this.onRemoveEmployee,
    required this.onPromoteEmployee,
    required this.onCopyCellContent,
    this.onUpdateAdjustedDate,
    this.onUpdatePromReason,
    required this.scrollController,
    this.isLoadingMore = false,
    this.onCellSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataSource = _PromotionDataSource(
      data,
      columns.where((col) => !hiddenColumns.contains(col)).toList(),
      context: context,
      onRemoveEmployee: onRemoveEmployee,
      onPromoteEmployee: onPromoteEmployee,
      onUpdateAdjustedDate: onUpdateAdjustedDate,
      onUpdatePromReason: onUpdatePromReason,
      onCellSelected: onCellSelected,
      onCopyCellContent: onCopyCellContent,
    );

    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: Colors.blue.shade700,
        gridLineColor: Colors.grey.shade300,
        gridLineStrokeWidth: 1.0,
        selectionColor: Colors.grey.shade400,
        filterIconColor: Colors.white,
        sortIconColor: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            SfDataGrid(
              source: dataSource,
              columnWidthMode: ColumnWidthMode.fill, // Changed to fill
              columnWidthCalculationRange: ColumnWidthCalculationRange.allRows,
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
              onCellSecondaryTap: (details) {
                if (details.column.columnName != 'actions') {
                  final rowIndex = details.rowColumnIndex.rowIndex - 1;
                  if (rowIndex >= 0 && rowIndex < data.length) {
                    final cellValue =
                        data[rowIndex][details.column.columnName]?.toString() ??
                        '';

                    // Add to clipboard collection instead of replacing
                    dataSource.addToClipboard(cellValue);
                    final allValues = dataSource.getSelectedCellsAsText();
                    Clipboard.setData(ClipboardData(text: allValues));
                    onCopyCellContent(
                      'تم إضافة إلى الحافظة (${dataSource.clipboardValuesCount} عنصر)',
                    );
                  }
                }
              },
              onCellDoubleTap: (details) {
                if (details.column.columnName != 'actions') {
                  final rowIndex = details.rowColumnIndex.rowIndex - 1;
                  if (rowIndex >= 0 && rowIndex < data.length) {
                    final cellValue =
                        data[rowIndex][details.column.columnName]?.toString() ??
                        '';

                    // Clear clipboard and copy only this cell
                    dataSource.clearSelection();
                    Clipboard.setData(ClipboardData(text: cellValue));
                    onCopyCellContent('تم نسخ: $cellValue');
                  }
                }
              },
              verticalScrollController: scrollController,
              columns: _buildGridColumns(),
            ),
            if (isLoadingMore) _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    final visibleColumns =
        columns.where((col) => !hiddenColumns.contains(col)).map((column) {
          double minWidth = _getColumnWidth(
            column,
          ); // Add back minimum width calculation

          return GridColumn(
            columnName: column,
            columnWidthMode: ColumnWidthMode.auto,
            minimumWidth: minWidth, // Restore minimum width
            autoFitPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                columnNames[column] ?? column,
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

    // Add action columns with fixed widths
    if (visibleColumns.isNotEmpty) {
      visibleColumns.add(
        GridColumn(
          columnName: 'promote',
          width: 100.0,
          allowSorting: false,
          allowFiltering: false,
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: const Text(
              'ترقية',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );

      visibleColumns.add(
        GridColumn(
          columnName: 'actions',
          width: 100.0,
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
    }

    return visibleColumns;
  }

  // Add back the width calculation method
  double _getColumnWidth(String column) {
    switch (column) {
      case 'Badge_NO':
        return 120;
      case 'Employee_Name':
        return 200;
      case 'Bus_Line':
      case 'Depart_Text':
      case 'Position_Text':
      case 'Basic':
        return 180.0;
      case 'Status':
      case 'Grade':
        return 100.0;
      case 'Adjusted_Eligible_Date':
      case 'Last_Promotion_Dt':
        return 150.0;

      case 'New_Basic':
        return 120.0;
      case 'Next_Grade':
        return 100.0;
      case '4% Adj':
      case 'Annual_Increment':
        return 130.0;
      case 'Grade_Range':
      case 'Promotion_Band':
        return 140.0;
      case 'Prom_Reason':
        return 200.0;
      default:
        return 120.0;
    }
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        color: Colors.black.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              const Text('جاري تحميل المزيد...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final BuildContext context;
  final Function(String)? onRemoveEmployee;
  final Function(String)? onPromoteEmployee;
  final Function(String, String)? onUpdateAdjustedDate;
  final Function(String, String)? onUpdatePromReason;
  final Function(String)? onCellSelected;
  final Function(String)? onCopyCellContent;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  _PromotionDataSource(
    this._data,
    this._columns, {
    required this.context,
    this.onRemoveEmployee,
    this.onPromoteEmployee,
    this.onUpdateAdjustedDate,
    this.onUpdatePromReason,
    this.onCellSelected,
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

  // Add public getter for clipboard values count
  int get clipboardValuesCount => _clipboardValues.length;

  // Add public method to add to clipboard
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

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    // Add safety check for valid row index
    if (rowIndex < 0 || rowIndex >= _data.length) {
      // Return empty row if index is invalid
      return DataGridRowAdapter(
        color: Colors.white,
        cells: List.generate(_columns.length + 2, (index) => Container()),
      );
    }

    final record = _data[rowIndex];

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          Widget cellWidget;

          // Check if this is the Adjusted_Eligible_Date column
          if (dataGridCell.columnName == 'Adjusted_Eligible_Date' &&
              onUpdateAdjustedDate != null) {
            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap:
                    () =>
                        _showDatePicker(record, dataGridCell.value.toString()),
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
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.blue.shade700,
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
          }
          // Check if this is the Prom_Reason column
          else if (dataGridCell.columnName == 'Prom_Reason' &&
              onUpdatePromReason != null) {
            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap:
                    () => _showPromReasonEditor(
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
                          textDirection: TextDirection.rtl,
                          dataGridCell.value.toString().isNotEmpty
                              ? dataGridCell.value.toString()
                              : 'Click to edit',
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
                dataGridCell.value.toString(),
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            );
          }

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
            child: cellWidget,
          );
        }).toList();

    // Add promote button
    final badgeColumn = _columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => 'Badge_NO',
    );
    final badgeNo = record[badgeColumn]?.toString() ?? '';

    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
          onPressed:
              badgeNo.isNotEmpty && onPromoteEmployee != null
                  ? () => onPromoteEmployee!(badgeNo)
                  : null,
          tooltip: 'ترقية الموظف',
        ),
      ),
    );

    // Add remove button
    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
          onPressed:
              badgeNo.isNotEmpty && onRemoveEmployee != null
                  ? () => onRemoveEmployee!(badgeNo)
                  : null,
          tooltip: 'إزالة من قائمة الترقيات',
        ),
      ),
    );

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }

  void _showDatePicker(Map<String, dynamic> record, String currentDate) async {
    final badgeColumn = _columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => 'Badge_NO',
    );
    final badgeNo = record[badgeColumn]?.toString() ?? '';

    if (badgeNo.isEmpty || onUpdateAdjustedDate == null) return;

    // Simply call the callback - let the parent handle the date picker
    onUpdateAdjustedDate!(badgeNo, currentDate);
  }

  void _showPromReasonEditor(
    Map<String, dynamic> record,
    String currentReason,
  ) async {
    final badgeColumn = _columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => 'Badge_NO',
    );
    final badgeNo = record[badgeColumn]?.toString() ?? '';

    if (badgeNo.isEmpty || onUpdatePromReason == null) return;

    // Show text input dialog
    final controller = TextEditingController(text: currentReason);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تعديل سبب الترقية'),
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
                    labelText: 'سبب الترقية',
                    border: OutlineInputBorder(),
                    hintText: 'أدخل سبب الترقية...',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  textDirection: TextDirection.rtl,
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
      onUpdatePromReason!(badgeNo, result);
    }
  }
}
