import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/constants/transfers_constants.dart';
import 'package:hr/widgets/transfers/transfers_data_source.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'dart:async';

class TransfersDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Set<String> hiddenColumns;
  final Function(Map<String, dynamic>) onRemoveTransfer;
  final Function(Map<String, dynamic>)?
  onTransferEmployee; // New callback for direct transfer
  final Function(String, String, String) onUpdateField;
  final Function(String) onCopyCellContent;
  final bool Function(DataGridColumnDragDetails)? onColumnDragging;
  final Function(int)? onFilterChanged;

  const TransfersDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.hiddenColumns,
    required this.onRemoveTransfer,
    this.onTransferEmployee, // Optional callback for direct transfer
    required this.onUpdateField,
    required this.onCopyCellContent,
    this.onColumnDragging,
    this.onFilterChanged,
  }) : super(key: key);

  @override
  TransfersDataGridState createState() => TransfersDataGridState();

  // Public method to get filtered data - accessible from parent widget
  List<Map<String, dynamic>> getFilteredData() {
    final state = (key as GlobalKey<TransfersDataGridState>?)?.currentState;
    return state?.getFilteredData() ?? data;
  }
}

class TransfersDataGridState extends State<TransfersDataGrid> {
  final Map<String, double> _columnWidths = {};
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Timer? _scrollTimer;
  TransfersDataSource? _dataSource;
  int _filteredRecordCount = 0;
  bool _isUpdating = false; // Flag to prevent rendering during updates
  List<String> _visibleColumns =
      []; // Store visible columns to ensure consistency

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    _createDataSource(); // Add this
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

    _dataSource = TransfersDataSource(
      widget.data,
      _visibleColumns, // Use the stored visible columns
      context: context,
      onRemoveTransfer: widget.onRemoveTransfer,
      onTransferEmployee: widget.onTransferEmployee, // Pass the new callback
      onUpdateField: widget.onUpdateField,
      onCopyCellContent: widget.onCopyCellContent,
    );
  }

  // Add method to refresh the data grid
  void refreshDataGrid() {
    print('Manually refreshing data grid');
    _createDataSource();
    setState(() {});
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
  void didUpdateWidget(TransfersDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only recreate data source when data or columns actually change
    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns) ||
        !_setsEqual(oldWidget.hiddenColumns, widget.hiddenColumns)) {
      // Set updating flag and clear data source to prevent mismatched rendering
      _isUpdating = true;
      _dataSource = null;

      // Force immediate rebuild with null data source
      setState(() {});

      // Use a post-frame callback to recreate the data source
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _createDataSource();
          _initializeColumnWidths();
          _isUpdating = false;
          setState(() {});
        }
      });
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
                TransfersConstants.columnNames[column] ?? column,
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

  double _getColumnWidth(String column) {
    switch (column) {
      case 'S_NO':
        return 120;
      case 'Badge_NO':
        return 160;
      case 'Employee_Name':
      case 'Position_Description':
      case 'OrgUnit_Description':
      case 'Occupancy':
      case 'Bus_Line':
      case 'Depart_Text':
      case 'Position_Text':
      case 'Emp_Position_Code':
      case 'New_Bus_Line':
        return 220;
      default:
        return 150;
    }
  }

  void _updateColumnWidth(String columnName, double width) {
    setState(() {
      _columnWidths[columnName] = width;
    });
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
    for (final column in _visibleColumns) {
      _columnWidths[column] = _getColumnWidth(column);
    }
    _columnWidths['actions'] = 100.0;
  }

  // Add method to refresh data source
  void refreshDataSource() {
    _createDataSource();
    setState(() {
      _filteredRecordCount =
          _dataSource?.effectiveRows.length ?? widget.data.length;
    });
    // Notify parent screen
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(_filteredRecordCount);
    }
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
            const SizedBox(height: 8.0),
            Expanded(
              child:
                  _isUpdating || _dataSource == null
                      ? const Center(child: CircularProgressIndicator())
                      : SfDataGrid(
                        key: ValueKey(
                          '${widget.hiddenColumns.toString()}_${_dataSource.hashCode}',
                        ), // Force rebuild when columns change or data source changes
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
                        onColumnResizeUpdate: (
                          ColumnResizeUpdateDetails details,
                        ) {
                          setState(() {
                            _columnWidths[details.column.columnName] =
                                details.width;
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
                            _filteredRecordCount =
                                _dataSource!.effectiveRows.length;
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
}
