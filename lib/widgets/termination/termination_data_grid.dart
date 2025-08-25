import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/constants/termination_constants.dart';
import 'package:hr/widgets/termination/termination_data_source.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class TerminationDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Set<String> hiddenColumns;
  final Function(Map<String, dynamic>) onRemoveTermination;
  final Function(String) onCopyCellContent;
  final bool Function(DataGridColumnDragDetails)? onColumnDragging;
  final Function(String, String)? onUpdateAppraisalText;
  final Function(int)? onFilterChanged;
  final Function(Map<String, dynamic>)? onTransferToTerminated; // Add this

  const TerminationDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.hiddenColumns,
    required this.onRemoveTermination,
    required this.onCopyCellContent,
    this.onColumnDragging,
    this.onUpdateAppraisalText,
    this.onFilterChanged,
    this.onTransferToTerminated, // Add this
  }) : super(key: key);

  @override
  TerminationDataGridState createState() => TerminationDataGridState();

  // Public method to get filtered data - accessible from parent widget
  List<Map<String, dynamic>> getFilteredData() {
    final state = (key as GlobalKey<TerminationDataGridState>?)?.currentState;
    return state?.getFilteredData() ?? data;
  }
}

class TerminationDataGridState extends State<TerminationDataGrid> {
  final Map<String, double> _columnWidths = {};
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Timer? _scrollTimer;
  TerminationDataSource? _dataSource;
  int _filteredRecordCount = 0;
  List<String> _visibleColumns =
      []; // Store visible columns to ensure consistency

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    _createDataSource();
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = widget.data.length;
      });
    });
  }

  void _createDataSource() {
    // Calculate visible columns once and store them for consistency
    _visibleColumns =
        widget.columns
            .where((col) => !widget.hiddenColumns.contains(col))
            .toList();

    _dataSource = TerminationDataSource(
      widget.data,
      _visibleColumns, // Use the stored visible columns
      onRemoveTermination: widget.onRemoveTermination,
      onCopyCellContent: widget.onCopyCellContent,
      onUpdateAppraisalText: widget.onUpdateAppraisalText,
      onTransferToTerminated: widget.onTransferToTerminated, // Add this
    );
  }

  // Add method to refresh data source
  void refreshDataSource() {
    _createDataSource();
    // Update filtered count to match the new data length
    setState(() {
      _filteredRecordCount =
          _dataSource?.effectiveRows.length ?? widget.data.length;
    });
    // Notify parent screen with updated count
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(_filteredRecordCount);
    }
  }

  @override
  void didUpdateWidget(TerminationDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate data source when data or columns change
    print('didUpdateWidget called');
    print('Old hidden columns count: ${oldWidget.hiddenColumns.length}');
    print('New hidden columns count: ${widget.hiddenColumns.length}');

    // Find differences
    final addedHidden = widget.hiddenColumns.difference(
      oldWidget.hiddenColumns,
    );
    final removedHidden = oldWidget.hiddenColumns.difference(
      widget.hiddenColumns,
    );

    if (addedHidden.isNotEmpty) {
      print('Newly hidden columns: $addedHidden');
    }
    if (removedHidden.isNotEmpty) {
      print('Newly visible columns: $removedHidden');
    }

    // FORCE recreation for debugging - remove this later
    print('FORCING data source recreation for debugging');
    _createDataSource();
    _initializeColumnWidths();
    setState(() {});

    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns) ||
        !_setsEqual(oldWidget.hiddenColumns, widget.hiddenColumns)) {
      _createDataSource();
      // Also update column widths for hidden columns
      _initializeColumnWidths();
      // Force a rebuild of the widget
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _initializeColumnWidths() {
    _columnWidths.clear();
    for (final column in widget.columns) {
      if (!widget.hiddenColumns.contains(column)) {
        _columnWidths[column] = _getColumnWidth(column);
      }
    }
    _columnWidths['actions'] = 100.0;
  }

  double _getColumnWidth(String column) {
    switch (column) {
      case 'Badge_NO':
        return 140;
      case 'Employee_Name':
        return 220;
      case 'Grade':
        return 120;
      case 'Old_Basic':
      case 'Adjustment':
      case 'Termination_Date':
      case 'Old_Basic_Plus_Adj':
      case 'Adjust_Date':
      case 'Annual_Increment':
      case 'Appraisal_Amount':
      case 'Appraisal_Date':
      case 'New_Basic':
      case 'Adjust_Months':
        return 180;
      case 'Appraisal_NO_of_Months':
        return 250;
      case 'Appraisal_Text':
        return 180;
      default:
        return 150;
    }
  }

  void _updateColumnWidth(String columnName, double width) {
    setState(() {
      _columnWidths[columnName] = width;
    });
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

  List<GridColumn> _buildGridColumns() {
    // Use the same visible columns that were used to create the data source
    final columns =
        _visibleColumns.map((column) {
          return GridColumn(
            columnName: column,
            width: _columnWidths[column] ?? _getColumnWidth(column),
            minimumWidth: 50,
            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                TerminationConstants.columnNames[column] ?? column,
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

    // Add actions column
    columns.add(
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

    return columns;
  }

  // Add method to get the actual filtered data
  List<Map<String, dynamic>> getFilteredData() {
    if (_dataSource == null) return widget.data;

    final effectiveRows = _dataSource!.effectiveRows;
    final filteredData = <Map<String, dynamic>>[];

    // Map each filtered row back to original data using the row index
    for (final row in effectiveRows) {
      final rowIndex = _dataSource!.rows.indexOf(row);
      if (rowIndex >= 0 && rowIndex < widget.data.length) {
        filteredData.add(widget.data[rowIndex]);
      }
    }

    return filteredData;
  }

  @override
  Widget build(BuildContext context) {
    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: AppColors.primaryColor,
        gridLineColor: Colors.grey.shade300,
        gridLineStrokeWidth: 1.0,
        selectionColor: Colors.grey.shade400,
        filterIconColor: Colors.white,
        sortIconColor: Colors.white,
        columnDragIndicatorColor: AppColors.primaryColor,
        columnDragIndicatorStrokeWidth: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Record count display
            _buildRecordCountBar(),
            Expanded(
              child: SfDataGrid(
                key: ValueKey(
                  widget.hiddenColumns.toString(),
                ), // Force rebuild when columns change
                source: _dataSource!,
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
                rowHeight: 50,
                headerRowHeight: 55,
                allowColumnsResizing: true,
                columnResizeMode: ColumnResizeMode.onResize,
                onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                  setState(() {
                    _columnWidths[details.column.columnName] = details.width;
                  });
                  return true;
                },
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
                  // Update filtered count and force UI refresh
                  setState(() {
                    _filteredRecordCount = _dataSource!.effectiveRows.length;
                  });

                  // Notify parent screen
                  if (widget.onFilterChanged != null) {
                    widget.onFilterChanged!(_filteredRecordCount);
                  }
                },
                onColumnDragging: widget.onColumnDragging,
                columns: _buildGridColumns(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = widget.data.length;
    final displayedRecords =
        _filteredRecordCount > 0 ? _filteredRecordCount : totalRecords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryColor.withAlpha(90)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.primaryColor),
            const SizedBox(width: 8),
            if (_filteredRecordCount > 0 &&
                _filteredRecordCount != totalRecords)
              Text(
                'عرض $displayedRecords من أصل $totalRecords سجل',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              )
            else
              Text(
                'إجمالي السجلات: $totalRecords',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              ),
            const Spacer(),
            if (_filteredRecordCount > 0 &&
                _filteredRecordCount != totalRecords)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'مفلتر',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
