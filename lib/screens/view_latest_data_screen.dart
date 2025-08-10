import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class ViewLatestDataScreen extends StatefulWidget {
  final Database? db;
  final String? tableName;

  const ViewLatestDataScreen({
    Key? key,
    required this.db,
    required this.tableName,
  }) : super(key: key);

  @override
  State<ViewLatestDataScreen> createState() => _ViewLatestDataScreenState();
}

class _ViewLatestDataScreenState extends State<ViewLatestDataScreen> {
  List<Map<String, dynamic>> _latestData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late DataGridSource _dataSource;
  final Set<String> _hiddenColumns = <String>{};

  // Empty column names mapping since we're using original column names
  final Map<String, String> _columnNames = {};

  // Add column widths map
  late Map<String, double> _columnWidths = {};

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Timer? _scrollTimer;

  int _filteredRecordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLatestData();
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = _latestData.length;
      });
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _horizontalController.dispose();
    _verticalController.dispose();
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

  Future<void> _loadLatestData() async {
    if (widget.db == null || widget.tableName == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Database or table not available';
      });
      print(
        "Database or table name is null: db=${widget.db}, tableName=${widget.tableName}",
      );
      return;
    }

    try {
      print("Loading data from table: ${widget.tableName}");

      // First determine the badge column name for ordering
      String badgeColumnName = '';
      try {
        final tableInfo = await widget.db!.rawQuery(
          'PRAGMA table_info("${widget.tableName}")',
        );
        badgeColumnName = tableInfo
            .map((col) => col['name'].toString())
            .firstWhere(
              (name) => name.toLowerCase().contains('badge'),
              orElse: () => 'Badge_NO',
            );
        print("Using badge column for ordering: $badgeColumnName");
      } catch (e) {
        print("Error finding badge column: $e");
        badgeColumnName = 'Badge_NO'; // Default if we can't determine
      }

      final orderBy =
          badgeColumnName.isNotEmpty
              ? 'CAST("$badgeColumnName" AS INTEGER) ASC'
              : 'id ASC';

      // First, check if the table exists and has data
      final tableCheck = await widget.db!.rawQuery(
        "SELECT count(*) as count FROM \"${widget.tableName}\"",
      );
      final recordCount = tableCheck.first['count'] as int? ?? 0;
      print("Table ${widget.tableName} has $recordCount records");

      if (recordCount == 0) {
        setState(() {
          _isLoading = false;
          _latestData = [];
        });
        return;
      }

      // Get the latest upload_date
      final latestDateQuery = await widget.db!.rawQuery(
        'SELECT MAX(upload_date) as latest_date FROM "${widget.tableName}" WHERE upload_date IS NOT NULL',
      );

      final latestDate = latestDateQuery.first['latest_date']?.toString();
      print("Latest upload_date: $latestDate");

      if (latestDate == null || latestDate.isEmpty) {
        setState(() {
          _isLoading = false;
          _latestData = [];
          _errorMessage = 'No records found with upload date';
        });
        return;
      }

      // Get all records with the latest upload_date
      final data = await widget.db!.rawQuery(
        '''
        SELECT t1.* FROM "${widget.tableName}" t1
        WHERE t1.upload_date = ?
        ORDER BY $orderBy
        ''',
        [latestDate],
      );

      print(
        "Query returned ${data.length} records with latest upload_date: $latestDate",
      );

      if (data.isEmpty) {
        setState(() {
          _latestData = [];
          _isLoading = false;
          _errorMessage =
              'No records found for the latest upload date: $latestDate';
        });
        return;
      }

      _columns = data.first.keys.toList();
      print("Columns found: $_columns");

      setState(() {
        _latestData = data;
        _isLoading = false;
        _errorMessage = '';
        _refreshDataSource();
      });
    } catch (e) {
      print("Error loading data: $e");

      // Try a fallback approach - get latest record per badge number
      try {
        // Determine badge column again for fallback
        String badgeColumnName = '';
        try {
          final tableInfo = await widget.db!.rawQuery(
            'PRAGMA table_info("${widget.tableName}")',
          );
          badgeColumnName = tableInfo
              .map((col) => col['name'].toString())
              .firstWhere(
                (name) => name.toLowerCase().contains('badge'),
                orElse: () => 'Badge_NO',
              );
        } catch (e) {
          badgeColumnName = 'Badge_NO'; // Default if we can't determine
        }

        final orderBy =
            badgeColumnName.isNotEmpty
                ? 'CAST(t1."$badgeColumnName" AS INTEGER) ASC'
                : 't1.id ASC';

        final allData = await widget.db!.rawQuery('''
          SELECT t1.* FROM "${widget.tableName}" t1
          INNER JOIN (
            SELECT t2."$badgeColumnName", MAX(t2.id) as max_id
            FROM "${widget.tableName}" t2
            GROUP BY t2."$badgeColumnName"
          ) t3 ON t1."$badgeColumnName" = t3."$badgeColumnName" AND t1.id = t3.max_id
          ORDER BY $orderBy
        ''');

        if (allData.isNotEmpty) {
          print("Fallback query returned ${allData.length} records");
          _columns = allData.first.keys.toList();

          setState(() {
            _latestData = allData;
            _isLoading = false;
            _refreshDataSource();
          });
          return;
        }
      } catch (fallbackError) {
        print("Fallback also failed: $fallbackError");
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: ${e.toString()}';
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (widget.tableName == null || _latestData.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Get filtered data
    final dataToExport = _getFilteredDataForExport();

    // Create a list of columns without the ID column
    final exportColumns = _columns.where((col) => col != 'id').toList();

    await ExcelExporter.exportToExcel(
      context: context,
      data: dataToExport,
      columns: exportColumns,
      columnNames: _columnNames,
      tableName:
          dataToExport.length < _latestData.length
              ? "${widget.tableName!}_latest_upload_مفلتر"
              : "${widget.tableName!}_latest_upload",
    );

    setState(() {
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getFilteredDataForExport() {
    // Get the actual filtered data from the data source
    if (_filteredRecordCount == 0 ||
        _filteredRecordCount == _latestData.length) {
      return _latestData;
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
      final matchingRecord = _latestData.firstWhere(
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
    // Check if key fields match (using badge number as primary identifier)
    if (rowData.containsKey('Badge_NO') && record.containsKey('Badge_NO')) {
      return record['Badge_NO']?.toString() == rowData['Badge_NO']?.toString();
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

  // Method to copy cell content to clipboard
  void _copyCellContent(String content) {
    CustomSnackbar.showInfo(context, content);
  }

  // Initialize column widths when columns are loaded
  void _initializeColumnWidths() {
    _columnWidths = {};
    for (final column in _columns) {
      if (column != 'Prom_Reason' &&
          column != 'id' &&
          !_hiddenColumns.contains(column)) {
        _columnWidths[column] = _getInitialColumnWidth(column);
      }
    }
  }

  void _refreshDataSource() {
    final visibleColumns =
        _columns
            .where(
              (column) =>
                  column !=
                      'Prom_Reason' && // Exclude Prom_Reason from latest data view
                  column != 'id' && // Exclude id column from view
                  !_hiddenColumns.contains(column),
            )
            .toList();

    _dataSource = _LatestDataSource(
      _latestData,
      visibleColumns,
      onCellSelected: _onCellSelected,
      onCopyCellContent: _copyCellContent,
    );

    // Reinitialize column widths when data source changes
    _initializeColumnWidths();
    setState(() {}); // Trigger rebuild
  }

  void _onCellSelected(String cellValue) {
    setState(() {}); // Refresh to show selection changes
  }

  void _copySelectedCells() {
    final latestDataSource = _dataSource as _LatestDataSource;
    final selectedText = latestDataSource.getSelectedCellsAsText();

    if (selectedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: selectedText));
      CustomSnackbar.showSuccess(
        context,
        'تم نسخ ${latestDataSource.selectedCellsCount} عنصر',
      );
    }
  }

  void _clearSelection() {
    final latestDataSource = _dataSource as _LatestDataSource;
    latestDataSource.clearSelection();
    setState(() {});
  }

  void _showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns:
                _columns
                    .where(
                      (column) => (column != 'Prom_Reason' && column != 'id'),
                    )
                    .toList(), // Exclude Prom_Reason
            columnNames: _columnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: _refreshDataSource,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_latestData.isEmpty) {
      return const Center(child: Text('لا توجد بيانات في آخر رفع للملف.'));
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header without copy/clear buttons
            SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Positioned(
                    top: 2,
                    right: 0,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: SizedBox(
                        height: 35,
                        child: Row(
                          children: [
                            // Column visibility button
                            ElevatedButton.icon(
                              onPressed: _showColumnVisibilityDialog,
                              icon: const Icon(
                                Icons.visibility,
                                color: Colors.white,
                              ),
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
                              icon: const Icon(
                                Icons.file_download,
                                color: Colors.white,
                              ),
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
                  ),
                ],
              ),
            ),

            // Data grid
            Expanded(
              child: Column(
                children: [
                  // Record count bar
                  _buildRecordCountBar(),
                  // Data grid
                  Expanded(
                    child: SfDataGridTheme(
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
                              source: _dataSource,
                              columnWidthMode: ColumnWidthMode.none,
                              allowSorting: true,
                              allowFiltering: true,
                              allowColumnsDragging: true,
                              selectionMode: SelectionMode.single,
                              showHorizontalScrollbar: true,
                              showVerticalScrollbar: true,
                              isScrollbarAlwaysShown: true,
                              gridLinesVisibility: GridLinesVisibility.both,
                              headerGridLinesVisibility:
                                  GridLinesVisibility.both,
                              rowHeight: 50,
                              headerRowHeight: 55,
                              allowColumnsResizing: true,
                              columnResizeMode: ColumnResizeMode.onResize,
                              onFilterChanged: (
                                DataGridFilterChangeDetails details,
                              ) {
                                setState(() {
                                  _filteredRecordCount =
                                      _dataSource.effectiveRows.length;
                                });
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
                              onColumnDragging: (
                                DataGridColumnDragDetails details,
                              ) {
                                if (details.action ==
                                        DataGridColumnDragAction.dropped &&
                                    details.to != null) {
                                  final visibleColumns =
                                      _columns
                                          .where(
                                            (column) =>
                                                column != 'Prom_Reason' &&
                                                column != 'id' &&
                                                !_hiddenColumns.contains(
                                                  column,
                                                ),
                                          )
                                          .toList();

                                  final rearrangedColumn =
                                      visibleColumns[details.from];
                                  visibleColumns.removeAt(details.from);
                                  visibleColumns.insert(
                                    details.to!,
                                    rearrangedColumn,
                                  );

                                  // Update the main columns list to preserve order
                                  final newColumns = <String>[];
                                  for (final column in _columns) {
                                    if (column == 'Prom_Reason' ||
                                        column == 'id' ||
                                        _hiddenColumns.contains(column)) {
                                      newColumns.add(column);
                                    }
                                  }

                                  // Insert visible columns in new order
                                  for (
                                    int i = 0;
                                    i < visibleColumns.length;
                                    i++
                                  ) {
                                    if (!newColumns.contains(
                                      visibleColumns[i],
                                    )) {
                                      newColumns.insert(
                                        newColumns.length,
                                        visibleColumns[i],
                                      );
                                    }
                                  }

                                  setState(() {
                                    _columns = newColumns;
                                  });

                                  _refreshDataSource();
                                }
                                return true;
                              },
                              columnDragFeedbackBuilder: (context, column) {
                                return Container(
                                  width:
                                      _columnWidths[column.columnName] ?? 180,
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
                              onCellSecondaryTap: (details) {
                                final rowIndex =
                                    details.rowColumnIndex.rowIndex - 1;
                                if (rowIndex >= 0 &&
                                    rowIndex < _latestData.length) {
                                  final cellValue =
                                      _latestData[rowIndex][details
                                              .column
                                              .columnName]
                                          ?.toString() ??
                                      '';

                                  // Add to clipboard collection instead of replacing
                                  final latestDataSource =
                                      _dataSource as _LatestDataSource;
                                  latestDataSource.addToClipboard(cellValue);
                                  final allValues =
                                      latestDataSource.getSelectedCellsAsText();
                                  Clipboard.setData(
                                    ClipboardData(text: allValues),
                                  );
                                  _copyCellContent(
                                    'تم إضافة إلى الحافظة (${latestDataSource.clipboardValuesCount} عنصر)',
                                  );
                                }
                              },
                              onCellDoubleTap: (details) {
                                final rowIndex =
                                    details.rowColumnIndex.rowIndex - 1;
                                if (rowIndex >= 0 &&
                                    rowIndex < _latestData.length) {
                                  final cellValue =
                                      _latestData[rowIndex][details
                                              .column
                                              .columnName]
                                          ?.toString() ??
                                      '';

                                  // Clear clipboard and copy only this cell
                                  final latestDataSource =
                                      _dataSource as _LatestDataSource;
                                  latestDataSource.clearSelection();
                                  Clipboard.setData(
                                    ClipboardData(text: cellValue),
                                  );
                                  _copyCellContent('تم نسخ: $cellValue');
                                }
                              },
                              horizontalScrollController: _horizontalController,
                              verticalScrollController: _verticalController,
                              columns: _buildGridColumns(),
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
                                          _verticalController,
                                          -50,
                                        ),
                                    onTapUp: (_) => _stopContinuousScroll(),
                                    onTapCancel: () => _stopContinuousScroll(),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor.withAlpha(
                                          200,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
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
                                          _verticalController,
                                          50,
                                        ),
                                    onTapUp: (_) => _stopContinuousScroll(),
                                    onTapCancel: () => _stopContinuousScroll(),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor.withAlpha(
                                          200,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
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
                                          -50,
                                        ),
                                    onTapUp: (_) => _stopContinuousScroll(),
                                    onTapCancel: () => _stopContinuousScroll(),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor.withAlpha(
                                          200,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_left,
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
                                          50,
                                        ),
                                    onTapUp: (_) => _stopContinuousScroll(),
                                    onTapCancel: () => _stopContinuousScroll(),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor.withAlpha(
                                          200,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_right,
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    // Initialize column widths if not done yet
    if (_columnWidths.isEmpty) {
      _initializeColumnWidths();
    }

    return _columns
        .where(
          (column) =>
              column != 'Prom_Reason' &&
              column != 'id' &&
              !_hiddenColumns.contains(column),
        )
        .map(
          (column) => GridColumn(
            columnName: column,
            width: _columnWidths[column] ?? _getInitialColumnWidth(column),
            minimumWidth: 20,
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        )
        .toList();
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

  Widget _buildRecordCountBar() {
    final totalRecords = _latestData.length;
    final displayedRecords =
        _filteredRecordCount > 0 ? _filteredRecordCount : totalRecords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
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
}

class _LatestDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Set<String> _clipboardValues = <String>{};
  final Function(String)? onCellSelected;
  final Function(String)? onCopyCellContent;
  List<DataGridRow> _dataGridRows = [];

  _LatestDataSource(
    this._data,
    this._columns, {
    this.onCellSelected,
    this.onCopyCellContent,
  }) {
    _dataGridRows =
        _data
            .map<DataGridRow>(
              (dataRow) => DataGridRow(
                cells:
                    _columns.map<DataGridCell>((column) {
                      String value = dataRow[column]?.toString() ?? '';

                      // Format upload_date column to match Base_Sheet format
                      if (column == 'upload_date' && value.isNotEmpty) {
                        try {
                          final dateTime = DateTime.parse(value);
                          final year = dateTime.year;
                          final month = dateTime.month;
                          final day = dateTime.day;
                          final hour =
                              dateTime.hour > 12
                                  ? dateTime.hour - 12
                                  : (dateTime.hour == 0 ? 12 : dateTime.hour);
                          final minute = dateTime.minute.toString().padLeft(
                            2,
                            '0',
                          );
                          final period = dateTime.hour >= 12 ? 'pm' : 'am';

                          value = '$year-$month-$day $hour:$minute$period';
                        } catch (e) {
                          // Keep original value if parsing fails
                        }
                      }

                      return DataGridCell<String>(
                        columnName: column,
                        value: value,
                      );
                    }).toList(),
              ),
            )
            .toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  void clearSelection() {
    _clipboardValues.clear();
  }

  String getSelectedCellsAsText() {
    return _clipboardValues.join('\n');
  }

  int get selectedCellsCount => _clipboardValues.length;

  // Add public getter for clipboard values count
  int get clipboardValuesCount => _clipboardValues.length;

  // Add public method to add to clipboard
  void addToClipboard(String value) {
    _clipboardValues.add(value);
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = rows.indexOf(row);

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells:
          row.getCells().map<Widget>((dataGridCell) {
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
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  dataGridCell.value.toString(),
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
    );
  }
}
