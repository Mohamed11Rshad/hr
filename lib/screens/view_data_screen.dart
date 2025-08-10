import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/services/database_service.dart';
import 'package:hr/utils/data_processor.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/widgets/table_data_source.dart';
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

class ViewDataScreen extends StatefulWidget {
  final Database? db;

  const ViewDataScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen> {
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  late TableDataSource _dataSource;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  Timer? _scrollTimer;
  final int _pageSize = 80;
  final Set<String> _processedBadgeNumbers = {};
  String? _lastCopiedCellInfo;

  // Arabic column names mapping
  final Map<String, String> _arabicColumnNames = {
    'badge_no': 'رقم الشارة',
    'name': 'الاسم',
    'department': 'القسم',
    'position': 'المنصب',
    // Add more mappings as needed
  };

  // Add a set to track hidden columns
  final Set<String> _hiddenColumns = <String>{};
  final Set<String> _selectedCells = <String>{};

  // Add column widths map
  late Map<String, double> _columnWidths = {};

  int _filteredRecordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTables();
    _verticalScrollController.addListener(_scrollListener);
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = _tableData.length;
      });
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _verticalScrollController.removeListener(_scrollListener);
    _verticalScrollController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_verticalScrollController.position.pixels ==
        _verticalScrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || _selectedTable == null) return;
    await _loadTableData(_selectedTable!, loadMore: true);
  }

  Future<void> _loadTables() async {
    if (widget.db == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'قاعدة البيانات غير مهيأة';
      });
      return;
    }

    try {
      if (!widget.db!.isOpen) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'قاعدة البيانات مغلقة - يرجى إعادة تشغيل التطبيق';
        });
        return;
      }

      await widget.db!.rawQuery('SELECT 1');

      final allTables = await DatabaseService.getAvailableTables(widget.db!);

      // Filter out internal tables (tables used by the application internally)
      final internalTables = {'promoted_employees', 'promotions', 'transfers'};

      final tables =
          allTables.where((table) => !internalTables.contains(table)).toList();

      setState(() {
        _tables = tables;
        _isLoading = false;
        if (tables.isNotEmpty) {
          _selectedTable = 'Base_Sheet';
          _loadTableData(_selectedTable!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل الجداول: ${e.toString()}';
      });
    }
  }

  Future<void> _loadTableData(String tableName, {bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _tableData = [];
        _columns = [];
        _processedBadgeNumbers.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final offset = loadMore ? _tableData.length : 0;

      // Find badge column for ordering
      String orderByClause = 'id'; // Default ordering
      if (_columns.isNotEmpty) {
        final badgeColumn = _columns.firstWhere(
          (col) => col.toLowerCase().contains('badge'),
          orElse: () => '',
        );
        if (badgeColumn.isNotEmpty) {
          orderByClause = '"$badgeColumn" ASC';
        }
      }

      final data = await widget.db!.query(
        tableName,
        limit: _pageSize,
        offset: offset,
        orderBy: orderByClause,
      );

      if (data.isEmpty) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      if (data.isNotEmpty && !loadMore) {
        _columns = data.first.keys.toList();
      }

      final processedData = DataProcessor.processAndMarkDifferentCells(
        data,
        _columns,
        _processedBadgeNumbers,
        existingData: _tableData,
        checkExisting: loadMore,
      );

      setState(() {
        if (!loadMore) {
          _tableData = processedData;
        } else {
          for (final record in processedData) {
            if (!_tableData.any((existing) => existing['id'] == record['id'])) {
              _tableData.add(record);
            }
          }
        }
        _isLoading = false;
        _isLoadingMore = false;
        _refreshDataSource();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    if (widget.db == null || _selectedTable == null) return;

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('حذف'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      // Delete from database
      await widget.db!.delete(
        _selectedTable!,
        where: 'id = ?',
        whereArgs: [record['id']],
      );

      // Update UI by removing the record and refreshing data source
      setState(() {
        _tableData.removeWhere((item) => item['id'] == record['id']);
        // Refresh the data source with proper column synchronization
        _refreshDataSource();
      });

      // Show success message
      CustomSnackbar.showSuccess(context, 'تم حذف العنصر بنجاح');
    } catch (e) {
      // Show error message
      CustomSnackbar.showError(context, 'خطأ في حذف العنصر: ${e.toString()}');
    }
  }

  Future<void> _exportToExcel() async {
    if (_selectedTable == null) return;

    setState(() {
      _isLoading = true;
    });

    // Get filtered data from data source
    final dataToExport = _getFilteredDataForExport();

    // Create a list of columns excluding ID and Prom_Reason
    final exportColumns =
        _columns
            .where(
              (col) =>
                  col != 'id' &&
                  col != 'Prom_Reason' &&
                  !col.endsWith('_highlighted'),
            )
            .toList();

    await ExcelExporter.exportToExcel(
      context: context,
      data: dataToExport,
      columns: exportColumns,
      columnNames: _arabicColumnNames,
      tableName:
          dataToExport.length < _tableData.length
              ? '${_selectedTable!}_مفلتر'
              : _selectedTable!,
    );

    setState(() {
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getFilteredDataForExport() {
    // Get the actual filtered data from the data source
    if (_filteredRecordCount == 0 ||
        _filteredRecordCount == _tableData.length) {
      return _tableData;
    }

    // Get the effective (filtered) rows from the data source
    final effectiveRows = _dataSource.effectiveRows;
    final filteredData = <Map<String, dynamic>>[];

    // Extract the actual data from each filtered row
    for (final row in effectiveRows) {
      final Map<String, dynamic> rowData = {};

      // Get data from each cell in the row
      for (final cell in row.getCells()) {
        final columnName = cell.columnName;
        final value = cell.value;

        // Skip action columns and add actual data
        if (columnName != 'actions') {
          rowData[columnName] = value;
        }
      }

      // Find the complete record from original data that matches this filtered row
      final matchingRecord = _tableData.firstWhere(
        (record) => _recordMatches(record, rowData),
        orElse: () => rowData,
      );

      filteredData.add(matchingRecord);
    }

    return filteredData;
  }

  // Helper method to check if a record matches the filtered row data
  bool _recordMatches(
    Map<String, dynamic> record,
    Map<String, dynamic> rowData,
  ) {
    // Check if key fields match (using badge number or ID as primary identifier)
    final badgeColumn = _columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => 'id',
    );

    if (rowData.containsKey(badgeColumn) && record.containsKey(badgeColumn)) {
      return record[badgeColumn]?.toString() ==
          rowData[badgeColumn]?.toString();
    }

    // Fallback: check if multiple fields match
    int matchCount = 0;
    int totalFields = 0;

    for (final key in rowData.keys) {
      if (record.containsKey(key)) {
        totalFields++;
        if (record[key]?.toString() == rowData[key]?.toString()) {
          matchCount++;
        }
      }
    }

    // Consider it a match if most fields are identical
    return totalFields > 0 && (matchCount / totalFields) > 0.8;
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  // Add method to refresh data source with current column visibility
  void _refreshDataSource() {
    if (_tableData.isEmpty) {
      // Handle empty data case
      _dataSource = TableDataSource(
        [],
        [],
        _arabicColumnNames,
        onDeleteRecord: _deleteRecord,
        onCellSelected: _onCellSelected,
        onCopyCellContent: _copyCellContent,
      );
      return;
    }

    final visibleColumns =
        _columns
            .where(
              (column) =>
                  column != 'id' &&
                  !column.endsWith('_highlighted') &&
                  column != 'Prom_Reason' &&
                  !_hiddenColumns.contains(column),
            )
            .toList();

    _dataSource = TableDataSource(
      _tableData,
      visibleColumns,
      _arabicColumnNames,
      onDeleteRecord: _deleteRecord,
      onCellSelected: _onCellSelected,
      onCopyCellContent: _copyCellContent,
    );

    // Reinitialize column widths when data source changes
    _initializeColumnWidths();
  }

  void _onCellSelected(String cellValue) {
    setState(() {}); // Refresh to show selection changes
  }

  // Initialize column widths when columns are loaded
  void _initializeColumnWidths() {
    _columnWidths = {};
    for (final column in _columns) {
      if (column != 'id' &&
          column != 'Prom_Reason' &&
          !column.endsWith('_highlighted') &&
          !_hiddenColumns.contains(column)) {
        _columnWidths[column] = _getInitialColumnWidth(column);
      }
    }
    // Add actions column
    _columnWidths['actions'] = 80.0;
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_tables.isEmpty) {
      return const Center(
        child: Text('لا توجد جداول متاحة. يرجى رفع ملفات إكسل أولاً.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with buttons
          if (_selectedTable != null) _buildHeaderButtons(),
          const SizedBox(height: 8),

          // Data grid
          Expanded(
            child:
                _tableData.isEmpty
                    ? const Center(
                      child: Text('لا توجد بيانات متاحة لهذا الجدول.'),
                    )
                    : Column(
                      children: [
                        // Record count bar
                        _buildRecordCountBar(),
                        // Data grid
                        Expanded(
                          child: Stack(
                            children: [
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: SfDataGridTheme(
                                  data: SfDataGridThemeData(
                                    headerColor: Colors.blue.shade700,
                                    gridLineColor: Colors.grey.shade300,
                                    gridLineStrokeWidth: 1.0,
                                    selectionColor: Colors.blue.shade100,
                                    sortIconColor: Colors.white,
                                    filterIconColor: Colors.white,
                                    headerHoverColor: Colors.black.withAlpha(
                                      50,
                                    ),
                                    filterIconHoverColor: Colors.black,
                                    columnDragIndicatorColor: Colors.black,
                                    columnDragIndicatorStrokeWidth: 4,
                                  ),
                                  child: SfDataGrid(
                                    source: _dataSource,
                                    columnWidthMode: ColumnWidthMode.none,
                                    allowSorting: true,
                                    allowFiltering: true,
                                    allowColumnsDragging: true,
                                    selectionMode: SelectionMode.single,
                                    allowPullToRefresh: true,
                                    showHorizontalScrollbar: true,
                                    isScrollbarAlwaysShown: true,
                                    showVerticalScrollbar: true,
                                    gridLinesVisibility:
                                        GridLinesVisibility.both,
                                    headerGridLinesVisibility:
                                        GridLinesVisibility.both,
                                    rowHeight: 50,
                                    headerRowHeight: 55,
                                    frozenColumnsCount: 1,
                                    allowColumnsResizing: true,
                                    columnResizeMode: ColumnResizeMode.onResize,
                                    horizontalScrollController:
                                        _horizontalController,
                                    onFilterChanged: (
                                      DataGridFilterChangeDetails details,
                                    ) {
                                      setState(() {
                                        _filteredRecordCount =
                                            _dataSource.effectiveRows.length;
                                      });
                                    },
                                    onColumnDragging: (
                                      DataGridColumnDragDetails details,
                                    ) {
                                      if (details.action ==
                                              DataGridColumnDragAction
                                                  .dropped &&
                                          details.to != null) {
                                        final visibleColumns =
                                            _columns
                                                .where(
                                                  (column) =>
                                                      !column.endsWith(
                                                        '_highlighted',
                                                      ) &&
                                                      column != 'id' &&
                                                      column != 'Prom_Reason' &&
                                                      !_hiddenColumns.contains(
                                                        column,
                                                      ),
                                                )
                                                .toList();

                                        // Don't allow dragging the actions column
                                        if (details.from >=
                                            visibleColumns.length)
                                          return true;

                                        final rearrangedColumn =
                                            visibleColumns[details.from];
                                        visibleColumns.removeAt(details.from);
                                        visibleColumns.insert(
                                          details.to!,
                                          rearrangedColumn,
                                        );

                                        // Update the main columns list
                                        final newColumns = <String>[];
                                        for (final column in _columns) {
                                          if (column.endsWith('_highlighted') ||
                                              column == 'id' ||
                                              column == 'Prom_Reason' ||
                                              _hiddenColumns.contains(column)) {
                                            newColumns.add(column);
                                          }
                                        }

                                        for (final column in visibleColumns) {
                                          if (!newColumns.contains(column)) {
                                            newColumns.add(column);
                                          }
                                        }

                                        setState(() {
                                          _columns = newColumns;
                                        });

                                        _refreshDataSource();
                                      }
                                      return true;
                                    },
                                    onColumnResizeUpdate: (
                                      ColumnResizeUpdateDetails details,
                                    ) {
                                      setState(() {
                                        _columnWidths[details
                                                .column
                                                .columnName] =
                                            details.width;
                                      });
                                      return true;
                                    },
                                    onCellSecondaryTap: (details) {
                                      // Skip action column
                                      if (details.column.columnName !=
                                          'actions') {
                                        final rowIndex =
                                            details.rowColumnIndex.rowIndex - 1;
                                        if (rowIndex >= 0 &&
                                            rowIndex < _tableData.length) {
                                          final cellValue =
                                              _tableData[rowIndex][details
                                                      .column
                                                      .columnName]
                                                  ?.toString() ??
                                              '';

                                          // Add to clipboard collection instead of replacing
                                          _dataSource.addToClipboard(cellValue);
                                          final allValues =
                                              _dataSource
                                                  .getSelectedCellsAsText();
                                          Clipboard.setData(
                                            ClipboardData(text: allValues),
                                          );
                                          _copyCellContent(
                                            'تم إضافة إلى الحافظة (${_dataSource.clipboardValuesCount} عنصر)',
                                          );
                                        }
                                      }
                                    },
                                    columnDragFeedbackBuilder: (
                                      context,
                                      column,
                                    ) {
                                      return Container(
                                        width:
                                            _columnWidths[column.columnName] ??
                                            180,
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
                                    onCellDoubleTap: (details) {
                                      // Skip action column
                                      if (details.column.columnName !=
                                          'actions') {
                                        final rowIndex =
                                            details.rowColumnIndex.rowIndex - 1;
                                        if (rowIndex >= 0 &&
                                            rowIndex < _tableData.length) {
                                          final cellValue =
                                              _tableData[rowIndex][details
                                                      .column
                                                      .columnName]
                                                  ?.toString() ??
                                              '';

                                          // Clear clipboard and copy only this cell
                                          _dataSource.clearSelection();
                                          Clipboard.setData(
                                            ClipboardData(text: cellValue),
                                          );
                                          _copyCellContent(
                                            'تم نسخ: $cellValue',
                                          );
                                        }
                                      }
                                    },
                                    verticalScrollController:
                                        _verticalScrollController,
                                    columns: _buildGridColumns(),
                                  ),
                                ),
                              ),
                              // Vertical scroll arrows - aligned with scrollbar
                              Positioned(
                                right: 0,
                                top: 75,
                                bottom: 20,
                                child: Column(
                                  children: [
                                    InkWell(
                                      onTapDown:
                                          (_) => _startContinuousScroll(
                                            _verticalScrollController,
                                            -50,
                                          ),
                                      onTapUp: (_) => _stopContinuousScroll(),
                                      onTapCancel:
                                          () => _stopContinuousScroll(),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor
                                              .withAlpha(200),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.keyboard_arrow_up,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTapDown:
                                          (_) => _startContinuousScroll(
                                            _verticalScrollController,
                                            50,
                                          ),
                                      onTapUp: (_) => _stopContinuousScroll(),
                                      onTapCancel:
                                          () => _stopContinuousScroll(),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor
                                              .withAlpha(200),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Horizontal scroll arrows - aligned with scrollbar
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: 0,
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTapDown:
                                          (_) => _startContinuousScroll(
                                            _horizontalController,
                                            50,
                                          ),
                                      onTapUp: (_) => _stopContinuousScroll(),
                                      onTapCancel:
                                          () => _stopContinuousScroll(),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor
                                              .withAlpha(200),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.keyboard_arrow_right,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),

                                    InkWell(
                                      onTapDown:
                                          (_) => _startContinuousScroll(
                                            _horizontalController,
                                            -50,
                                          ),
                                      onTapUp: (_) => _stopContinuousScroll(),
                                      onTapCancel:
                                          () => _stopContinuousScroll(),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor
                                              .withAlpha(200),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.keyboard_arrow_left,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButtons() {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          Positioned(
            top: 2,
            right: 0,
            child: SizedBox(
              height: 35,
              child: Row(
                children: [
                  // Column visibility button
                  ElevatedButton.icon(
                    onPressed: _showColumnVisibilityDialog,
                    icon: const Icon(Icons.visibility, color: Colors.white),
                    label: const Text(
                      'إظهار/إخفاء الأعمدة',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export button
                  ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.file_download, color: Colors.white),
                    label: const Text(
                      'إستخراج بصيغة Excel',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = _tableData.length;
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
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          if (_filteredRecordCount > 0 && _filteredRecordCount != totalRecords)
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

  // Add method to show column visibility dialog
  void _showColumnVisibilityDialog() {
    final visibleColumns =
        _columns
            .where(
              (column) =>
                  !column.endsWith('_highlighted') &&
                  column != 'id' &&
                  column !=
                      'Prom_Reason', // Exclude Prom_Reason from column visibility options
            )
            .toList();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('إظهار/إخفاء الأعمدة'),
                  content: SizedBox(
                    width: double.maxFinite.clamp(0, 800),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Add "Select All" checkbox
                        CheckboxListTile(
                          title: const Text('تحديد الكل'),
                          value: _hiddenColumns.isEmpty,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              setState(() {
                                if (value == true) {
                                  // Show all columns
                                  _hiddenColumns.clear();
                                } else {
                                  // Hide all columns
                                  _hiddenColumns.addAll(visibleColumns);
                                }
                              });
                            });

                            // Refresh the data source
                            _refreshDataSource();
                          },
                        ),
                        const Divider(),
                        // List of columns
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: visibleColumns.length,
                            itemBuilder: (context, index) {
                              final column = visibleColumns[index];
                              final displayName =
                                  _arabicColumnNames[column] ?? column;

                              return CheckboxListTile(
                                title: Text(displayName),
                                value: !_hiddenColumns.contains(column),
                                onChanged: (bool? value) {
                                  // Update both the dialog state and the widget state
                                  setDialogState(() {
                                    setState(() {
                                      if (value == false) {
                                        _hiddenColumns.add(column);
                                      } else {
                                        _hiddenColumns.remove(column);
                                      }
                                    });
                                  });

                                  // Refresh the data source with updated column visibility
                                  _refreshDataSource();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Update the _buildGridColumns method to use stored widths
  List<GridColumn> _buildGridColumns() {
    // Initialize column widths if not done yet
    if (_columnWidths.isEmpty) {
      _initializeColumnWidths();
    }

    final columns =
        _columns
            .where(
              (column) =>
                  !column.endsWith('_highlighted') &&
                  column != 'id' &&
                  column != 'Prom_Reason' &&
                  !_hiddenColumns.contains(column),
            )
            .map((column) {
              return GridColumn(
                columnName: column,
                width: _columnWidths[column] ?? _getInitialColumnWidth(column),
                minimumWidth: 20,
                label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: Text(
                    _arabicColumnNames[column] ?? column,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            })
            .toList();

    // Only add delete column if there are other visible columns
    if (columns.isNotEmpty) {
      columns.add(
        GridColumn(
          columnName: 'actions',
          minimumWidth: 20,

          width: _columnWidths['actions'] ?? 80.0,
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

    return columns;
  }

  // Add method to determine initial column widths
  double _getInitialColumnWidth(String column) {
    switch (column.toLowerCase()) {
      case 'badge_no':
      case 'badge no':
        return 180;
      case 'employee_name':
      case 'employee name':
      case 'name':
        return 250;
      case 'basic':
      case 'salary':
        return 180;
      case 'grade':
        return 120;
      case 'department':
      case 'dept':
      case 'depart_text':
        return 180.0;
      case 'position':
      case 'position_text':
      case 'bus_line':
      case 'upload_date':
        return 200;
      case 'adjusted_eligible_date':
      case 'last_promotion_dt':
        return 160.0;
      default:
        return 180; // Default width for other columns
    }
  }

  // Update the _loadTableData method to call _refreshDataSource

  void _copyCellContent(String content) {
    CustomSnackbar.showInfo(context, content);
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
}
