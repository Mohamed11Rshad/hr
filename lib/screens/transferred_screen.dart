import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/services/transfers_data_service.dart';
import 'package:hr/constants/transfers_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class TransferredScreen extends StatefulWidget {
  final Database? db;
  final String? tableName;

  const TransferredScreen({Key? key, required this.db, this.tableName})
      : super(key: key);

  @override
  State<TransferredScreen> createState() => _TransferredScreenState();
}

class _TransferredScreenState extends State<TransferredScreen> {
  List<Map<String, dynamic>> _transferredData = [];
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
  late TransfersDataService _dataService;

  // Add a set to track hidden columns
  final Set<String> _hiddenColumns = <String>{};

  List<String> _columns = [
    'S_NO',
    'Badge_NO',
    'Employee_Name',
    'Position_Code',
    'POD',
    'ERD',
    'DONE_YES_NO',
    'Available_in_ERD',
    'Bus_Line',
    'Depart_Text',
    'Grade',
    'Grade_Range',
    'Position_Text',
    'Emp_Position_Code',
    'Dept',
    'Position_Abbreviation',
    'Position_Description',
    'OrgUnit_Description',
    'Grade_Range6',
    'New_Bus_Line',
    'Grade_GAP',
    'Transfer_Type',
    'Occupancy',
    'Badge_Number',
    'transfer_date',
    'created_date',
  ];

  static const Map<String, String> _columnNames = {
    'S_NO': 'S No',
    'Badge_NO': 'Badge No',
    'Employee_Name': 'Employee Name',
    'Position_Code': 'Position Code',
    'POD': 'POD',
    'ERD': 'ERD',
    'DONE_YES_NO': 'Status',
    'Available_in_ERD': 'Available in ERD',
    'Bus_Line': 'Bus Line',
    'Depart_Text': 'Department',
    'Grade': 'Grade',
    'Grade_Range': 'Grade Range',
    'Position_Text': 'Position',
    'Emp_Position_Code': 'Emp Position Code',
    'Dept': 'Dept',
    'Position_Abbreviation': 'Position Abbr',
    'Position_Description': 'Position Desc',
    'OrgUnit_Description': 'Org Unit',
    'Grade_Range6': 'Grade Range 6',
    'New_Bus_Line': 'New Bus Line',
    'Grade_GAP': 'Grade GAP',
    'Transfer_Type': 'Transfer Type',
    'Occupancy': 'Occupancy',
    'Badge_Number': 'Badge Number',
    'transfer_date': 'Transfer Date',
    'created_date': 'Created Date',
  };

  // Add column widths map
  late Map<String, double> _columnWidths = {};

  // Filtered record count
  int _filteredRecordCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    if (widget.db != null && widget.tableName != null) {
      _dataService = TransfersDataService(
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
        _filteredRecordCount = _transferredData.length;
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
        return 150.0;
      case 'Employee_Name':
        return 200.0;
      case 'Grade':
        return 100.0;
      case 'Old_Position_Code':
      case 'Current_Position_Code':
        return 150.0;
      case 'Old_Position':
      case 'Current_Position':
        return 200.0;
      case 'Transfer_Type':
        return 130.0;
      case 'POD':
      case 'ERD':
      case 'Available_in_ERD':
        return 120.0;
      case 'transferred_date':
        return 150.0;
      default:
        return 180.0;
    }
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await _dataService.initializeTransfersTable();
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
      _transferredData.clear();
    });

    await _loadMoreData();
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final data = await _dataService.getTransferredEmployees(
        limit: 50,
        offset: _currentPage * 50,
      );

      setState(() {
        if (_currentPage == 0) {
          _transferredData = data;
        } else {
          _transferredData.addAll(data);
        }
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
        _hasMoreData = data.length == 50;
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
    if (_transferredData.isNotEmpty) {
      _dataSource = _TransferredDataSource(
        _transferredData,
        _columns.where((col) => !_hiddenColumns.contains(col)).toList(),
        onRemoveEmployee: _removeTransferredEmployeeRecord,
        onCopyCellContent: _copyCellContent,
      );
    }
  }

  Future<void> _removeTransferredEmployeeRecord(
    Map<String, dynamic> record,
  ) async {
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final transferredDate = record['transfer_date']?.toString() ??
        ''; // Changed from 'transferred_date' to 'transfer_date'

    final confirmed = await _showConfirmationDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف الموظف ذو الرقم $badgeNo من قائمة المنقولين؟',
    );

    if (confirmed != true) return;

    try {
      print(
          'Attempting to remove transferred employee: $badgeNo, transfer_date: $transferredDate');
      await _dataService.removeTransferredEmployee(badgeNo, transferredDate);
      print('Successfully removed from database');

      setState(() {
        print(
            'Removing from local list. List size before: ${_transferredData.length}');

        // First try to remove by Badge_NO and transfer_date
        int initialLength = _transferredData.length;
        _transferredData.removeWhere(
          (item) =>
              item['Badge_NO']?.toString() == badgeNo &&
              item['transfer_date']?.toString() == transferredDate,
        );

        // If nothing was removed, try by Badge_NO only
        if (_transferredData.length == initialLength) {
          print(
              'No item removed by Badge_NO and transfer_date, trying Badge_NO only');
          _transferredData.removeWhere(
            (item) => item['Badge_NO']?.toString() == badgeNo,
          );
        }

        print('List size after removal: ${_transferredData.length}');
        _refreshDataSource();
      });

      CustomSnackbar.showSuccess(context, 'تم حذف الموظف من قائمة المنقولين');
    } catch (e) {
      print('Error removing transferred employee: $e');
      CustomSnackbar.showError(context, 'خطأ في حذف الموظف: ${e.toString()}');
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      columnNames: _columnNames,
      tableName: dataToExport.length < _transferredData.length
          ? 'الموظفين_المنقولين_مفلتر'
          : 'الموظفين_المنقولين',
    );

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFilteredDataForExport() {
    // Get the actual filtered data from the data source
    if (_filteredRecordCount == 0 ||
        _filteredRecordCount == _transferredData.length) {
      return _transferredData;
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
      final matchingRecord = _transferredData.firstWhere(
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

  void _showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => ColumnVisibilityDialog(
        columns: _columns,
        columnNames: _columnNames,
        hiddenColumns: _hiddenColumns,
        onVisibilityChanged: () {
          setState(() {
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
    if (_transferredData.isEmpty) {
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
                  child: SfDataGrid(
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
                        _filteredRecordCount = _dataSource.effectiveRows.length;
                      });
                    },
                    onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                      setState(() {
                        _columnWidths[details.column.columnName] =
                            details.width;
                      });
                      return true;
                    },
                    onColumnDragging: (DataGridColumnDragDetails details) {
                      if (details.action == DataGridColumnDragAction.dropped &&
                          details.to != null) {
                        final visibleColumns = _columns
                            .where((col) => !_hiddenColumns.contains(col))
                            .toList();

                        // Don't allow dragging the actions column
                        if (details.from >= visibleColumns.length) return true;

                        final rearrangedColumn = visibleColumns[details.from];
                        visibleColumns.removeAt(details.from);
                        visibleColumns.insert(details.to!, rearrangedColumn);

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
                    columnDragFeedbackBuilder: (context, column) {
                      return Container(
                        width: _columnWidths[column.columnName] ?? 180,
                        height: 50,
                        color: const Color.fromARGB(255, 23, 82, 25),
                        child: Center(
                          child: Text(
                            _columnNames[column.columnName] ??
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
                      onTapDown: (_) => _startContinuousScroll(
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
                      onTapDown: (_) => _startContinuousScroll(
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
                      onTapDown: (_) => _startContinuousScroll(
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
                      onTapDown: (_) =>
                          _startContinuousScroll(_horizontalController, 50),
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
      ],
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = _transferredData.length;
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
                'عرض $displayedRecords من أصل $totalRecords منقول',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              )
            else
              Text(
                'إجمالي المنقولين: $totalRecords',
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
            _columnNames[column] ?? column,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.transfer_within_a_station,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد موظفين منقولين',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'سيظهر هنا الموظفين الذين تم إكمال نقلهم من شاشة التنقلات',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
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

class _TransferredDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Function(Map<String, dynamic>)? onRemoveEmployee;
  final Function(String)? onCopyCellContent;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];

  _TransferredDataSource(
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

  int get clipboardValuesCount => _clipboardValues.length;

  void addToClipboard(String value) {
    _clipboardValues.add(value);
  }

  void _buildDataGridRows() {
    _dataGridRows = _data.map<DataGridRow>((dataRow) {
      return DataGridRow(
        cells: _columns.map<DataGridCell>((column) {
          String value = dataRow[column]?.toString() ?? '';

          // Format transferred_date for display
          if (column == 'transferred_date' && value.isNotEmpty) {
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
    final cells = _columns.map<Widget>((column) {
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

    // Add delete button
    if (_columns.isNotEmpty) {
      cells.add(
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onRemoveEmployee?.call(record),
            tooltip: 'حذف من قائمة المنقولين',
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
