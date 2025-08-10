import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hr/core/app_colors.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class PromotionDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Map<String, String> columnNames;
  final Set<String> hiddenColumns;
  final Function(String) onRemoveEmployee;
  final Function(String) onPromoteEmployee;
  final Function(String) onCopyCellContent;
  final Function(String, String) onUpdateAdjustedDate;
  final Function(String, String) onUpdatePromReason;
  final Function(DataGridColumnDragDetails)? onColumnDragging;
  final ScrollController? scrollController;
  final bool isLoadingMore;
  final Function(String)? onCellSelected;
  final Function(int)? onFilterChanged; // Add this

  const PromotionDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.columnNames,
    required this.hiddenColumns,
    required this.onRemoveEmployee,
    required this.onPromoteEmployee,
    required this.onCopyCellContent,
    required this.onUpdateAdjustedDate,
    required this.onUpdatePromReason,
    this.onColumnDragging,
    this.scrollController,
    this.isLoadingMore = false,
    this.onCellSelected,
    this.onFilterChanged, // Add this
  }) : super(key: key);

  @override
  PromotionDataGridState createState() => PromotionDataGridState();

  // Public method to get filtered data - accessible from parent widget
  List<Map<String, dynamic>> getFilteredData() {
    final state = (key as GlobalKey<PromotionDataGridState>?)?.currentState;
    if (state != null) {
      return state.getFilteredDataForExport();
    }
    return data;
  }
}

class PromotionDataGridState extends State<PromotionDataGrid> {
  late Map<String, double> _columnWidths = {};
  final ScrollController _horizontalController = ScrollController();
  Timer? _scrollTimer;
  late _PromotionDataSource _dataSource; // Add this

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    _createDataSource(); // Add this
  }

  void _createDataSource() {
    _dataSource = _PromotionDataSource(
      widget.data,
      widget.columns
          .where((col) => !widget.hiddenColumns.contains(col))
          .toList(),
      context: context,
      onRemoveEmployee: widget.onRemoveEmployee,
      onPromoteEmployee: widget.onPromoteEmployee,
      onUpdateAdjustedDate: widget.onUpdateAdjustedDate,
      onUpdatePromReason: widget.onUpdatePromReason,
      onCellSelected: widget.onCellSelected,
      onCopyCellContent: widget.onCopyCellContent,
    );
  }

  // Public getter to access the data source
  _PromotionDataSource get dataSource => _dataSource;

  @override
  void didUpdateWidget(PromotionDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate data source when data or columns change
    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns) ||
        !_setsEqual(oldWidget.hiddenColumns, widget.hiddenColumns)) {
      _createDataSource();
    }
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  bool _setsEqual(Set<String> set1, Set<String> set2) {
    return set1.length == set2.length && set1.containsAll(set2);
  }

  void _initializeColumnWidths() {
    _columnWidths = {};
    final visibleColumns = widget.columns.where(
      (col) => !widget.hiddenColumns.contains(col),
    );

    for (final column in visibleColumns) {
      _columnWidths[column] = _getColumnWidth(column);
    }

    // Add action columns
    _columnWidths['promote'] = 100.0;
    _columnWidths['actions'] = 100.0;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _horizontalController.dispose();
    super.dispose();
  }

  void _startContinuousScroll(ScrollController controller, double delta) {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (controller.hasClients) {
        final newOffset = (controller.offset + delta).clamp(
          0.0,
          controller.position.maxScrollExtent,
        );
        controller.jumpTo(newOffset);
      }
    });
  }

  void _stopContinuousScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  // Method to get filtered data for export
  List<Map<String, dynamic>> getFilteredDataForExport() {
    final effectiveRows = _dataSource.effectiveRows;
    final filteredData = <Map<String, dynamic>>[];

    // Extract data from each filtered row
    for (final row in effectiveRows) {
      final data = <String, dynamic>{};
      final cells = row.getCells();

      for (int i = 0; i < cells.length && i < widget.columns.length; i++) {
        final cell = cells[i];
        data[widget.columns[i]] = cell.value;
      }

      filteredData.add(data);
    }

    return filteredData;
  }

  @override
  Widget build(BuildContext context) {
    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: Colors.blue.shade700,
        gridLineColor: Colors.grey.shade300,
        gridLineStrokeWidth: 1.0,
        selectionColor: Colors.grey.shade400,
        filterIconColor: Colors.white,
        sortIconColor: Colors.white,
        columnDragIndicatorColor: Colors.black,
        columnDragIndicatorStrokeWidth: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SfDataGrid(
              source: _dataSource, // Use the stored data source
              columnWidthMode: ColumnWidthMode.none,
              allowSorting: true,
              allowFiltering: true,
              allowColumnsDragging: true,
              selectionMode: SelectionMode.single,
              showHorizontalScrollbar: true,
              showVerticalScrollbar: true,
              isScrollbarAlwaysShown: true,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
              rowHeight: 60,
              headerRowHeight: 65,
              allowColumnsResizing: true,
              columnResizeMode: ColumnResizeMode.onResize,
              columnDragFeedbackBuilder: (context, column) {
                return Container(
                  width: _columnWidths[column.columnName] ?? 180,
                  height: 50,
                  color: AppColors.primaryColor,
                  child: Center(
                    child: Text(
                      column.columnName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        decoration: TextDecoration.none,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
              onFilterChanged: (DataGridFilterChangeDetails details) {
                // Update filtered count and notify parent
                final filteredCount = _dataSource.effectiveRows.length;
                widget.onFilterChanged?.call(filteredCount);
                // Force a rebuild to refresh the UI
                setState(() {});
              },
              onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                setState(() {
                  _columnWidths[details.column.columnName] = details.width;
                });
                return true;
              },
              onColumnDragging: (DataGridColumnDragDetails details) {
                if (widget.onColumnDragging != null) {
                  return widget.onColumnDragging!(details);
                }
                return true;
              },
              columns: _buildGridColumns(),
            ),
            if (widget.isLoadingMore) _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        color: Colors.black.withAlpha(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 8),
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

  List<GridColumn> _buildGridColumns() {
    final visibleColumns =
        widget.columns.where((col) => !widget.hiddenColumns.contains(col)).map((
          column,
        ) {
          return GridColumn(
            columnName: column,
            minimumWidth: 20,
            width: _columnWidths[column] ?? _getColumnWidth(column),
            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                widget.columnNames[column] ?? column,
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

    // Add action columns with stored widths
    if (visibleColumns.isNotEmpty) {
      visibleColumns.add(
        GridColumn(
          columnName: 'promote',
          minimumWidth: 100,
          width: _columnWidths['promote'] ?? 100.0,
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
          width: _columnWidths['actions'] ?? 100.0,
          minimumWidth: 100,
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
        return 180;
      case 'Employee_Name':
        return 200;
      case 'Bus_Line':
      case 'Depart_Text':
      case 'Position_Text':
      case 'Basic':
        return 180.0;
      case 'Status':
      case 'Grade':
      case 'Adjusted_Eligible_Date':
      case 'Last_Promotion_Dt':
      case 'New_Basic':
      case 'Next_Grade':
      case '4% Adj':
      case 'Annual_Increment':
      case 'Grade_Range':
      case 'Promotion_Band':
        return 150.0;
      case 'Prom_Reason':
        return 200.0;
      // Add widths for the new remaining columns
      case 'Age__Hijra_':
      case 'Age__Gregorian_':
        return 120.0;
      case 'OrgUnit4':
      case 'OrgUnit1':
        return 140.0;
      case 'Position_Abbrv':
        return 120.0;
      case 'Certificate':
      case 'Educational_Est':
      case 'Institute_Location':
        return 180.0;
      case 'Date_of_Join':
      case 'Due_Date':
      case 'Recommended_Date':
      case 'Eligible_Date':
      case 'Retirement_Date__Grego_':
        return 160.0;
      case 'Nationality':
        return 120.0;
      case 'Service_in_KJO':
      case 'Period_Since_Last_Promotion':
      case 'Calculated_Year_for_Promotion':
        return 180.0;
      case 'Appraisal1':
      case 'Appraisal2':
      case 'Appraisal3':
      case 'Appraisal4':
      case 'Appraisal5':
        return 120.0;
      case 'GAP':
        return 100.0;
      case 'Meet_Requirement':
        return 140.0;
      case 'Missing_criteria':
        return 160.0;
      case 'Pay_scale_area_text':
        return 180.0;
      default:
        return 160; // Default width for any other columns
    }
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
    final isHighlighted = record['_highlighted'] == true;
    final validationType = record['_validation_type']?.toString() ?? '';

    // Parse validation types - handle multiple validation types separated by comma
    final validationTypes =
        validationType.split(',').map((e) => e.trim()).toSet();
    final hasBasicValidation = validationTypes.contains('basic_validation');
    final hasDateValidation = validationTypes.contains('date_validation');

    print(
      'Building row for record: Badge=${record['Badge_NO']}, highlighted=$isHighlighted, validationTypes=$validationTypes',
    ); // Debug

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
          Widget cellWidget;

          // Check if this is the Adjusted_Eligible_Date column
          if (dataGridCell.columnName == 'Adjusted_Eligible_Date' &&
              onUpdateAdjustedDate != null) {
            // Check if this cell should be highlighted for date validation
            final shouldHighlightDate = isHighlighted && hasDateValidation;

            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap:
                    onUpdateAdjustedDate != null
                        ? () => _showDatePicker(
                          record,
                          dataGridCell.value.toString(),
                        )
                        : null,

                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          shouldHighlightDate
                              ? Colors.redAccent.shade400
                              : Colors.blue.shade300,
                      width: shouldHighlightDate ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    color:
                        shouldHighlightDate
                            ? Colors.red.withAlpha(50)
                            : Colors.blue.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color:
                            shouldHighlightDate
                                ? Colors.redAccent.shade700
                                : Colors.blue.shade700,
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
                                shouldHighlightDate
                                    ? Colors.redAccent.shade700
                                    : dataGridCell.value.toString().isNotEmpty
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
            // Check if this specific cell should be highlighted (Old Basic validation)
            final shouldHighlightBasic =
                isHighlighted &&
                hasBasicValidation &&
                dataGridCell.columnName == 'Basic';

            print(
              'Cell ${dataGridCell.columnName}: shouldHighlightBasic=$shouldHighlightBasic (highlighted=$isHighlighted, hasBasicValidation=$hasBasicValidation)',
            ); // Debug

            cellWidget = Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              decoration:
                  shouldHighlightBasic
                      ? BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.red.shade300,
                          width: 2, // Make border more visible
                        ),
                      )
                      : null,
              child: Text(
                _formatDisplayValue(
                  dataGridCell.columnName,
                  dataGridCell.value.toString(),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      shouldHighlightBasic
                          ? FontWeight.bold
                          : FontWeight.normal,
                  color:
                      shouldHighlightBasic ? Colors.red.shade700 : Colors.black,
                ),
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

    // Use standard alternating row colors like view data screen
    Color rowColor = rowIndex % 2 == 0 ? Colors.white : Colors.grey.shade50;

    return DataGridRowAdapter(color: rowColor, cells: cells);
  }

  void _showDatePicker(Map<String, dynamic> record, String currentDate) async {
    final badgeColumn = _columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => 'Badge_NO',
    );
    final badgeNo = record[badgeColumn]?.toString() ?? '';

    if (badgeNo.isEmpty || onUpdateAdjustedDate == null) return;

    onUpdateAdjustedDate!(badgeNo, currentDate);
  }

  String _formatDisplayValue(String columnName, String value) {
    // List of numeric columns that should be displayed as integers
    const numericColumns = [
      'Basic',
      'New_Basic',
      '4% Adj',
      'Annual_Increment',
      'Grade',
      'Next_Grade',
      'Badge_NO',
    ];

    if (numericColumns.contains(columnName) && value.isNotEmpty) {
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue.round().toString();
      }
    }
    return value;
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
