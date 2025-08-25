import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/core/constants/app_constants.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

abstract class BaseDataGrid extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Set<String> hiddenColumns;
  final Function(String)? onCopyCellContent;
  final ScrollController? scrollController;
  final bool isLoadingMore;
  final Map<String, String>? columnNames;
  final bool showRecordCount; // Add this

  const BaseDataGrid({
    Key? key,
    required this.data,
    required this.columns,
    required this.hiddenColumns,
    this.onCopyCellContent,
    this.scrollController,
    this.isLoadingMore = false,
    this.columnNames,
    this.showRecordCount = true, // Add this
  }) : super(key: key);
}

abstract class BaseDataGridState<T extends BaseDataGrid> extends State<T> {
  late Map<String, double> _columnWidths = {};
  final ScrollController _horizontalController = ScrollController();
  Timer? _scrollTimer;
  int _filteredRecordCount = 0; // Add this

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = widget.data.length;
      });
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(T oldWidget) {
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
    _initializeColumnWidths();
    setState(() {});

    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns) ||
        !_setsEqual(oldWidget.hiddenColumns, widget.hiddenColumns)) {
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

  void _initializeColumnWidths() {
    _columnWidths = {};
    final visibleColumns = widget.columns.where(
      (col) => !widget.hiddenColumns.contains(col),
    );

    for (final column in visibleColumns) {
      _columnWidths[column] = getColumnWidth(column);
    }

    // Initialize action column widths
    initializeActionColumnWidths();
  }

  // Abstract methods to be implemented by subclasses
  double getColumnWidth(String column);
  void initializeActionColumnWidths();
  DataGridSource createDataSource();
  List<GridColumn> buildActionColumns();
  Color getHeaderColor();

  void _startContinuousScroll(ScrollController controller, double delta) {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(AppConstants.animationDuration ~/ 6, (timer) {
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

  @override
  Widget build(BuildContext context) {
    final dataSource = createDataSource();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SfDataGridTheme(
        data: SfDataGridThemeData(
          headerColor: getHeaderColor(),
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
              if (widget.showRecordCount) _buildRecordCountBar(),
              // Data grid
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SfDataGrid(
                      key: ValueKey(
                        widget.hiddenColumns.toString(),
                      ), // Force rebuild when columns change
                      source: dataSource,
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
                        // Update filtered record count
                        setState(() {
                          _filteredRecordCount =
                              dataSource.effectiveRows.length;
                        });
                      },
                      horizontalScrollController: _horizontalController,
                      verticalScrollController: widget.scrollController,
                      onCellSecondaryTap: _handleCellSecondaryTap,
                      onCellDoubleTap: _handleCellDoubleTap,
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
                      columns: _buildGridColumns(),
                    ),
                    ..._buildScrollArrows(),
                    if (widget.isLoadingMore) _buildLoadingIndicator(),
                  ],
                ),
              ),
            ],
          ),
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
        color: getHeaderColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: getHeaderColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: getHeaderColor()),
          const SizedBox(width: 8),
          if (_filteredRecordCount > 0 && _filteredRecordCount != totalRecords)
            Text(
              'عرض $displayedRecords من أصل $totalRecords سجل',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: getHeaderColor(),
              ),
            )
          else
            Text(
              'إجمالي الصفوف: $totalRecords',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: getHeaderColor(),
              ),
            ),
          const Spacer(),
          if (_filteredRecordCount > 0 && _filteredRecordCount != totalRecords)
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
    );
  }

  void _handleCellSecondaryTap(DataGridCellTapDetails details) {
    if (!_isActionColumn(details.column.columnName)) {
      final rowIndex = details.rowColumnIndex.rowIndex - 1;
      if (rowIndex >= 0 && rowIndex < widget.data.length) {
        final cellValue =
            widget.data[rowIndex][details.column.columnName]?.toString() ?? '';

        if (dataSource is ClipboardCapable) {
          (dataSource as ClipboardCapable).addToClipboard(cellValue);
          final allValues =
              (dataSource as ClipboardCapable).getSelectedCellsAsText();
          Clipboard.setData(ClipboardData(text: allValues));
          widget.onCopyCellContent?.call(
            'تم إضافة إلى الحافظة (${(dataSource as ClipboardCapable).clipboardValuesCount} عنصر)',
          );
        }
      }
    }
  }

  void _handleCellDoubleTap(DataGridCellDoubleTapDetails details) {
    if (!_isActionColumn(details.column.columnName)) {
      final rowIndex = details.rowColumnIndex.rowIndex - 1;
      if (rowIndex >= 0 && rowIndex < widget.data.length) {
        final cellValue =
            widget.data[rowIndex][details.column.columnName]?.toString() ?? '';

        if (dataSource is ClipboardCapable) {
          (dataSource as ClipboardCapable).clearSelection();
          Clipboard.setData(ClipboardData(text: cellValue));
          widget.onCopyCellContent?.call('تم نسخ: $cellValue');
        }
      }
    }
  }

  bool _isActionColumn(String columnName) {
    return columnName == 'actions' || columnName == 'promote';
  }

  late DataGridSource dataSource;

  List<Widget> _buildScrollArrows() {
    return [
      // Vertical scroll arrows
      Positioned(
        right: 0,
        top: 75,
        bottom: 20,
        child: Column(
          children: [
            _buildScrollArrow(
              icon: Icons.keyboard_arrow_up,
              onPressed:
                  () => _startContinuousScroll(
                    widget.scrollController ?? ScrollController(),
                    -50,
                  ),
            ),
            const Spacer(),
            _buildScrollArrow(
              icon: Icons.keyboard_arrow_down,
              onPressed:
                  () => _startContinuousScroll(
                    widget.scrollController ?? ScrollController(),
                    50,
                  ),
            ),
          ],
        ),
      ),
      // Horizontal scroll arrows
      Positioned(
        left: 20,
        right: 20,
        bottom: 0,
        child: Row(
          children: [
            _buildScrollArrow(
              icon: Icons.keyboard_arrow_left,
              onPressed:
                  () => _startContinuousScroll(_horizontalController, -50),
            ),
            const Spacer(),
            _buildScrollArrow(
              icon: Icons.keyboard_arrow_right,
              onPressed:
                  () => _startContinuousScroll(_horizontalController, 50),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildScrollArrow({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => _stopContinuousScroll(),
      onTapCancel: () => _stopContinuousScroll(),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withAlpha(200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    final columns =
        widget.columns.where((col) => !widget.hiddenColumns.contains(col)).map((
          column,
        ) {
          return GridColumn(
            columnName: column,
            width: _columnWidths[column] ?? getColumnWidth(column),
            minimumWidth: AppConstants.minColumnWidth,
            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                widget.columnNames?[column] ?? column,
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

    columns.addAll(buildActionColumns());
    return columns;
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
                  color: getHeaderColor(),
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

// Mixin for clipboard functionality
mixin ClipboardCapable {
  final Set<String> _clipboardValues = <String>{};

  void clearSelection() => _clipboardValues.clear();
  String getSelectedCellsAsText() => _clipboardValues.join('\n');
  int get clipboardValuesCount => _clipboardValues.length;
  void addToClipboard(String value) => _clipboardValues.add(value);
}
