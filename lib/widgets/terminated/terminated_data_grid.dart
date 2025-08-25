import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:hr/widgets/terminated/terminated_data_source.dart';
import 'package:hr/constants/terminated_constants.dart';

class TerminatedDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Set<String> hiddenColumns;
  final Function(Map<String, dynamic>)? onRemoveTerminated;
  final Function(String)? onCopyCellContent;
  final Function(String, String, String)? onUpdateDateField;
  final Function(List<String>)? onColumnsReordered; // Add this

  const TerminatedDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.hiddenColumns,
    this.onRemoveTerminated,
    this.onCopyCellContent,
    this.onUpdateDateField,
    this.onColumnsReordered, // Add this
  }) : super(key: key);

  @override
  State<TerminatedDataGrid> createState() => TerminatedDataGridState();
}

class TerminatedDataGridState extends State<TerminatedDataGrid> {
  late TerminatedDataSource _dataSource;
  final DataGridController _dataGridController = DataGridController();
  late Map<String, double> _columnWidths = {};
  late List<String> _currentColumns;

  @override
  void initState() {
    super.initState();
    _currentColumns = List.from(widget.columns);
    _initializeColumnWidths();
    _buildDataSource();
  }

  void _initializeColumnWidths() {
    _columnWidths = {};
    for (final column in widget.columns) {
      _columnWidths[column] = _getColumnWidth(column);
    }
    _columnWidths['Actions'] = 120.0;
  }

  double _getColumnWidth(String column) {
    switch (column) {
      case 'Badge_NO':
        return 180.0;
      case 'Employee_Name':
        return 220.0;
      case 'Grade':
        return 150.0;
      case 'Termination_Date':
        return 180.0;
      case 'F5':
      case 'F7':
      case 'F8':
        return 200.0;
      case 'Action_Date':
        return 150.0;
      default:
        return 180.0;
    }
  }

  void _buildDataSource() {
    final visibleColumns =
        widget.columns
            .where((col) => !widget.hiddenColumns.contains(col))
            .toList();

    _dataSource = TerminatedDataSource(
      widget.data,
      visibleColumns,
      onRemoveTerminated: widget.onRemoveTerminated,
      onCopyCellContent: widget.onCopyCellContent,
      onUpdateDateField: widget.onUpdateDateField,
    );
  }

  @override
  void didUpdateWidget(TerminatedDataGrid oldWidget) {
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
    _buildDataSource();
    _initializeColumnWidths();
    setState(() {});

    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns) ||
        !_setsEqual(oldWidget.hiddenColumns, widget.hiddenColumns)) {
      _buildDataSource();
      // Also update column widths for hidden columns
      _initializeColumnWidths();
      // Force a rebuild of the widget
      setState(() {});
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

  void refreshData() {
    _buildDataSource();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visibleColumns =
        widget.columns
            .where((col) => !widget.hiddenColumns.contains(col))
            .toList();

    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: Colors.green.shade700,
        gridLineColor: Colors.grey.shade300,
        gridLineStrokeWidth: 1.0,
        selectionColor: Colors.grey.shade400,
        filterIconColor: Colors.white,
        sortIconColor: Colors.white,
        columnDragIndicatorColor: const Color.fromARGB(255, 0, 65, 2),
        columnDragIndicatorStrokeWidth: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SfDataGrid(
          key: ValueKey(
            widget.hiddenColumns.toString(),
          ), // Force rebuild when columns change
          source: _dataSource,
          controller: _dataGridController,
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
          onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
            setState(() {
              _columnWidths[details.column.columnName] = details.width;
            });
            return true;
          },
          onColumnDragging: (DataGridColumnDragDetails details) {
            if (details.action == DataGridColumnDragAction.dropped &&
                details.to != null) {
              final visibleColumns =
                  widget.columns
                      .where((col) => !widget.hiddenColumns.contains(col))
                      .toList();

              // Don't allow dragging the actions column
              if (details.from >= visibleColumns.length) return true;

              final rearrangedColumn = visibleColumns[details.from];
              visibleColumns.removeAt(details.from);
              visibleColumns.insert(details.to!, rearrangedColumn);

              // Update the main columns list
              final newColumns = <String>[];
              for (final column in widget.columns) {
                if (widget.hiddenColumns.contains(column)) {
                  newColumns.add(column);
                }
              }
              for (final column in visibleColumns) {
                if (!newColumns.contains(column)) {
                  newColumns.add(column);
                }
              }

              // Notify parent about column reordering
              widget.onColumnsReordered?.call(newColumns);

              _buildDataSource();
              setState(() {});
            }
            return true;
          },
          columnDragFeedbackBuilder: (context, column) {
            return Container(
              width: _columnWidths[column.columnName] ?? 180,
              height: 50,
              color: const Color.fromARGB(255, 23, 82, 25),

              child: Center(
                child: Text(
                  TerminatedConstants.columnNames[column.columnName] ??
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
          columns: [
            ...visibleColumns.map((column) {
              return GridColumn(
                columnName: column,
                width: _columnWidths[column] ?? _getColumnWidth(column),
                label: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    TerminatedConstants.columnNames[column] ?? column,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
            // Actions column
            GridColumn(
              columnName: 'Actions',
              width: _columnWidths['Actions'] ?? 120.0,
              label: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8.0),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dataGridController.dispose();
    super.dispose();
  }
}
