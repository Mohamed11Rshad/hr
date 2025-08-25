import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/services/promotions_data_service.dart';
import 'package:hr/constants/promotion_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class PromotedScreen extends StatefulWidget {
  final Database? db;
  final String? tableName;

  const PromotedScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<PromotedScreen> createState() => _PromotedScreenState();
}

class _PromotedScreenState extends State<PromotedScreen> {
  List<Map<String, dynamic>> _promotedData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late DataGridSource _dataSource;

  // Pagination
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  Timer? _scrollTimer;

  // Services
  late PromotionsDataService _dataService;

  // Add a set to track hidden columns
  final Set<String> _hiddenColumns = <String>{};

  List<String> _columns = [
    'Badge_NO',
    'Employee_Name',
    'Grade',
    'Status',
    'Last_Promotion_Dt', // Keep only Last_Promotion_Dt, remove Adjusted_Eligible_Date
    'Prom_Reason',
    'promoted_date',
  ];

  // Add column widths map
  late Map<String, double> _columnWidths = {};

  // Filtered record count
  int _filteredRecordCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    if (widget.db != null && widget.tableName != null) {
      _dataService = PromotionsDataService(
        db: widget.db!,
        baseTableName: widget.tableName!,
      );
      _initializeAndLoadData();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'قاعدة البيانات أو اسم الجدول غير متوفر';
      });
    }
    _verticalScrollController.addListener(_scrollListener);
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = _promotedData.length;
      });
    });
  }

  void _initializeColumnWidths() {
    _columnWidths = {};
    for (final column in _columns) {
      _columnWidths[column] = _getColumnWidth(column);
    }
    _columnWidths['actions'] = 120.0;
  }

  double _getColumnWidth(String column) {
    switch (column) {
      case 'Badge_NO':
        return 180;
      case 'Employee_Name':
        return 200.0;
      case 'Grade':
      case 'Status':
      case 'Last_Promotion_Dt':
      case 'promoted_date':
        return 150.0;
      case 'Prom_Reason':
        return 200.0;
      default:
        return 180.0;
    }
  }

  Future<void> _initializeAndLoadData() async {
    try {
      // Initialize tables first
      await _dataService.initializePromotionsTable();
      // Then load data
      await _loadData();
    } catch (e) {
      print('Error in _initializeAndLoadData: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تهيئة قاعدة البيانات: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _verticalScrollController.dispose();
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

  void _scrollListener() {
    if (_verticalScrollController.position.pixels >=
            _verticalScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMoreData = true;
      _promotedData.clear();
    });

    await _loadMoreData();
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final data = await _dataService.getPromotedEmployees(
        limit: PromotionConstants.pageSize,
        offset: _currentPage * PromotionConstants.pageSize,
      );

      setState(() {
        if (_currentPage == 0) {
          _promotedData = data;
        } else {
          _promotedData.addAll(data);
        }
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
        _hasMoreData = data.length == PromotionConstants.pageSize;
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

  void _refreshDataSource() {
    if (_promotedData.isNotEmpty) {
      _dataSource = _PromotedDataSource(
        _promotedData,
        _columns
            .where((col) => !_hiddenColumns.contains(col))
            .toList(), // Only include visible columns
        onRemoveEmployee: _removePromotedEmployeeRecord,
        onCopyCellContent: _copyCellContent,
      );
    }
  }

  Future<void> _removePromotedEmployeeRecord(
    Map<String, dynamic> record,
  ) async {
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final promotedDate = record['promoted_date']?.toString() ?? '';

    final confirmed = await _showConfirmationDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف الموظف ذو الرقم $badgeNo من قائمة المرقين؟',
    );

    if (confirmed != true) return;

    try {
      // Remove from database first
      await _dataService.removePromotedEmployee(badgeNo, promotedDate);

      // Update UI by removing from local data and recreating data source
      setState(() {
        _promotedData.removeWhere(
          (item) =>
              item['Badge_NO']?.toString() == badgeNo &&
              item['promoted_date']?.toString() == promotedDate,
        );

        // Recreate data source with updated data
        _dataSource = _PromotedDataSource(
          _promotedData,
          _columns,
          onRemoveEmployee: _removePromotedEmployeeRecord,
          onCopyCellContent: _copyCellContent,
        );
      });

      CustomSnackbar.showSuccess(context, 'تم حذف الموظف من قائمة المرقين');
    } catch (e) {
      debugPrint(e.toString());
      CustomSnackbar.showError(context, 'خطأ في حذف الموظف: ${e.toString()}');
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
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
  }

  void _copyCellContent(String content) {
    CustomSnackbar.showInfo(context, content);
  }

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);

    // Get filtered data
    final dataToExport = _getFilteredDataForExport();

    await ExcelExporter.exportToExcel(
      context: context,
      data: dataToExport,
      columns: _columns,
      columnNames: PromotionConstants.promotedColumnNames,
      tableName:
          dataToExport.length < _promotedData.length
              ? 'الموظفين_المرقين_مفلتر'
              : 'الموظفين_المرقين',
    );

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFilteredDataForExport() {
    // Get the actual filtered data from the data source
    if (_filteredRecordCount == 0 ||
        _filteredRecordCount == _promotedData.length) {
      return _promotedData;
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
      final matchingRecord = _promotedData.firstWhere(
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

  // Add method to show column visibility dialog
  void _showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns: _columns,
            columnNames: PromotionConstants.promotedColumnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: () {
              setState(() {
                // Refresh the data source with updated column visibility
                _refreshDataSource();
              });
            },
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

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildHeader(), Expanded(child: _buildContent())],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
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
    );
  }

  Widget _buildContent() {
    if (_promotedData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Record count bar
        _buildRecordCountBar(),
        // Data grid
        Expanded(
          child: Stack(
            children: [
              SfDataGridTheme(
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
                        headerGridLinesVisibility: GridLinesVisibility.both,
                        rowHeight: 60,
                        headerRowHeight: 65,
                        allowColumnsResizing: true,
                        columnResizeMode: ColumnResizeMode.onResize,
                        onFilterChanged: (DataGridFilterChangeDetails details) {
                          setState(() {
                            _filteredRecordCount =
                                _dataSource.effectiveRows.length;
                          });
                        },
                        onColumnDragging: (DataGridColumnDragDetails details) {
                          if (details.action ==
                                  DataGridColumnDragAction.dropped &&
                              details.to != null) {
                            final visibleColumns =
                                _columns
                                    .where(
                                      (col) => !_hiddenColumns.contains(col),
                                    )
                                    .toList();

                            // Don't allow dragging the actions column
                            if (details.from >= visibleColumns.length)
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
                              if (_hiddenColumns.contains(column)) {
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
                            _columnWidths[details.column.columnName] =
                                details.width;
                          });
                          return true;
                        },
                        columnDragFeedbackBuilder: (context, column) {
                          return Container(
                            width: _columnWidths[column.columnName] ?? 180,
                            height: 50,
                            color: const Color.fromARGB(255, 23, 82, 25),
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
                        verticalScrollController: _verticalScrollController,
                        horizontalScrollController: _horizontalController,
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
                                    _verticalScrollController,
                                    -50,
                                  ),
                              onTapUp: (_) => _stopContinuousScroll(),
                              onTapCancel: () => _stopContinuousScroll(),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withAlpha(200),
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
                                    _verticalScrollController,
                                    50,
                                  ),
                              onTapUp: (_) => _stopContinuousScroll(),
                              onTapCancel: () => _stopContinuousScroll(),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withAlpha(200),
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
                                  color: AppColors.primaryColor.withAlpha(200),
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
                                  color: AppColors.primaryColor.withAlpha(200),
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
              if (_isLoadingMore) _buildLoadingIndicator(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = _promotedData.length;
    final displayedRecords =
        _filteredRecordCount > 0 ? _filteredRecordCount : totalRecords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade700.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade700.withOpacity(0.3)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 8),
            if (_filteredRecordCount > 0 &&
                _filteredRecordCount != totalRecords)
              Text(
                'عرض $displayedRecords من أصل $totalRecords مرقى',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              )
            else
              Text(
                'إجمالي المرقين: $totalRecords',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
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

  List<GridColumn> _buildGridColumns() {
    final columns =
        _columns.where((col) => !_hiddenColumns.contains(col)).map((column) {
          return GridColumn(
            columnName: column,
            width: _columnWidths[column] ?? _getColumnWidth(column),
            minimumWidth: 20,

            label: Container(
              padding: const EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                PromotionConstants.promotedColumnNames[column] ?? column,
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

    columns.add(
      GridColumn(
        columnName: 'actions',
        width: _columnWidths['actions'] ?? 120.0,
        minimumWidth: 20,

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
                  color: Colors.green.shade700,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد موظفين ',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'سيظهر هنا الموظفين الذين تم ترقيتهم من شاشة الترقيات',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _PromotedDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Function(Map<String, dynamic>)? onRemoveEmployee;
  final Function(String)? onCopyCellContent;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  _PromotedDataSource(
    this._data,
    this._columns, {
    this.onRemoveEmployee,
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
                  String value = dataRow[column]?.toString() ?? '';

                  // Format promoted_date for display
                  if (column == 'promoted_date' && value.isNotEmpty) {
                    try {
                      final date = DateTime.parse(value);
                      value =
                          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
                    } catch (e) {
                      // Keep original value if parsing fails
                    }
                  }

                  return DataGridCell<String>(columnName: column, value: value);
                }).toList(),
          );
        }).toList();
  }

  @override
  List<DataGridRow> get rows => List.from(_dataGridRows);

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);
    final record = _data[rowIndex];

    // Only build cells for visible columns (matching the _columns list)
    final cells =
        _columns.map<Widget>((column) {
          // Find the corresponding cell in the row
          final dataGridCell = row.getCells().firstWhere(
            (cell) => cell.columnName == column,
            orElse: () => DataGridCell(columnName: column, value: ''),
          );

          return GestureDetector(
            onSecondaryTap: () {
              final cellValue = dataGridCell.value.toString();
              _clipboardValues.add(cellValue);
              final allValues = _clipboardValues.join('\n');
              Clipboard.setData(ClipboardData(text: allValues));
              onCopyCellContent?.call(
                'تم إضافة إلى الحافظة (${_clipboardValues.length} عنصر)',
              );
            },
            onDoubleTap: () {
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
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList();

    // Add delete button - following the same pattern as TableDataSource
    if (_columns.isNotEmpty) {
      cells.add(
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onRemoveEmployee?.call(record),
            tooltip: 'حذف من قائمة المرقين',
          ),
        ),
      );
    }

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.green.shade50,
      cells: cells,
    );
  }
}
