import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hr/constants/appraisal_constants.dart';
import 'package:hr/widgets/appraisal/appraisal_data_source.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class AppraisalDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Set<String> hiddenColumns;
  final Function(String) onCopyCellContent;
  final bool Function(DataGridColumnDragDetails)? onColumnDragging;
  final Function(int)? onFilterChanged;
  final Function(int, String, String)? onCellValueChanged;

  const AppraisalDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.hiddenColumns,
    required this.onCopyCellContent,
    this.onColumnDragging,
    this.onFilterChanged,
    this.onCellValueChanged,
  }) : super(key: key);

  @override
  AppraisalDataGridState createState() => AppraisalDataGridState();

  // Public method to get filtered data - accessible from parent widget
  List<Map<String, dynamic>> getFilteredData() {
    final state = (key as GlobalKey<AppraisalDataGridState>?)?.currentState;
    return state?.getFilteredData() ?? data;
  }
}

class AppraisalDataGridState extends State<AppraisalDataGrid> {
  final Map<String, double> _columnWidths = {};
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Timer? _scrollTimer;
  AppraisalDataSource? _dataSource;
  int _filteredRecordCount = 0;
  bool _isUpdating = false; // Flag to prevent rendering during updates
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

    _dataSource = AppraisalDataSource(
      widget.data,
      _visibleColumns, // Use the stored visible columns
      onCopyCellContent: widget.onCopyCellContent,
      context: context,
      onCellValueChanged: (rowIndex, columnName, newValue) {
        // Update the underlying data
        if (rowIndex >= 0 && rowIndex < widget.data.length) {
          widget.data[rowIndex][columnName] = newValue;
          // Notify parent if callback is provided
          widget.onCellValueChanged?.call(rowIndex, columnName, newValue);
        }
      },
    );
  }

  // Add method to get the actual filtered data
  List<Map<String, dynamic>> getFilteredData() {
    if (_dataSource == null) {
      print('AppraisalDataGrid: DataSource is null in getFilteredData');
      return widget.data;
    }

    try {
      final effectiveRows = _dataSource!.effectiveRows;
      print(
        'AppraisalDataGrid: effectiveRows length in getFilteredData: ${effectiveRows.length}',
      );
      final filteredData = <Map<String, dynamic>>[];

      // Map each filtered row back to original data using the row index
      for (final row in effectiveRows) {
        final rowIndex = _dataSource!.rows.indexOf(row);
        if (rowIndex >= 0 && rowIndex < widget.data.length) {
          filteredData.add(widget.data[rowIndex]);
        }
      }

      print(
        'AppraisalDataGrid: Returning ${filteredData.length} filtered records',
      );
      return filteredData;
    } catch (e) {
      print('AppraisalDataGrid: Error in getFilteredData: $e');
      return widget.data;
    }
  }

  // Add refresh method
  void refresh() {
    // Instead of recreating data source, just notify it of changes
    _dataSource?.notifyListeners();
    setState(() {
      // Update filtered count
      if (_dataSource != null) {
        _filteredRecordCount = _dataSource!.effectiveRows.length;
      }
    });
  }

  @override
  void didUpdateWidget(AppraisalDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only recreate data source when data or columns actually change
    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns) ||
        !_setsEqual(oldWidget.hiddenColumns, widget.hiddenColumns)) {
      print('AppraisalDataGrid: Changes detected, recreating data source');

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
    } else {
      // No changes detected, skipping recreation
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

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _initializeColumnWidths() {
    _columnWidths.clear();
    final visibleColumns = widget.columns.where(
      (col) => !widget.hiddenColumns.contains(col),
    );

    for (final column in visibleColumns) {
      _columnWidths[column] = _getColumnWidth(column);
    }
  }

  double _getColumnWidth(String column) {
    switch (column) {
      case 'Badge_NO':
        return 180;
      case 'Employee_Name':
        return 220;
      case 'Bus_Line':
      case 'Depart_Text':
        return 180;
      case 'Grade':
        return 140;
      case 'Appraisal5':
        return 180;
      case 'Basic':
      case 'MIDPOINT':
      case 'MAXIMUM':
      case 'Annual_Increment':
      case 'Actual_Increase':
      case 'Lump_Sum_Payment':
      case 'New_Basic':
      case 'Total_Lump_Sum_12_Months':
        return 200;
      case 'New_Basic_System':
        return 200;
      default:
        return 180;
    }
  }

  List<GridColumn> _buildGridColumns() {
    // Use the same visible columns that were used to create the data source
    final visibleColumns =
        _visibleColumns.map((column) {
          return GridColumn(
            columnName: column,
            width: _columnWidths[column] ?? _getColumnWidth(column),
            minimumWidth: 50,
            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                AppraisalConstants.columnNames[column] ?? column,
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

    return visibleColumns;
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
        color: Colors.blue.shade700.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            if (_filteredRecordCount > 0 &&
                _filteredRecordCount != totalRecords)
              Text(
                'عرض $displayedRecords من أصل $totalRecords سجل',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              )
            else
              Text(
                'إجمالي السجلات: $totalRecords',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
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
                        allowColumnsResizing: true,
                        allowPullToRefresh: true,
                        columnResizeMode: ColumnResizeMode.onResize,
                        selectionMode: SelectionMode.single,
                        navigationMode: GridNavigationMode.cell,
                        showHorizontalScrollbar: true,
                        showVerticalScrollbar: true,
                        isScrollbarAlwaysShown: true,
                        gridLinesVisibility: GridLinesVisibility.both,
                        headerGridLinesVisibility: GridLinesVisibility.both,
                        rowHeight: 50,
                        headerRowHeight: 55,
                        columnDragFeedbackBuilder: (context, column) {
                          return Container(
                            width: _columnWidths[column.columnName] ?? 180,
                            height: 50,
                            color: Colors.blue.shade700,
                            child: Center(
                              child: Text(
                                AppraisalConstants.columnNames[column
                                        .columnName] ??
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
                        onColumnResizeUpdate: (
                          ColumnResizeUpdateDetails details,
                        ) {
                          setState(() {
                            _columnWidths[details.column.columnName] =
                                details.width;
                          });
                          return true;
                        },
                        onFilterChanged: (DataGridFilterChangeDetails details) {
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
