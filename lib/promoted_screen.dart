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

  // Services
  late PromotionsDataService _dataService;

  // Add a set to track hidden columns
  final Set<String> _hiddenColumns = <String>{};

  final List<String> _columns = [
    'Badge_NO',
    'Employee_Name',
    'Grade',
    'Status',
    'Adjusted_Eligible_Date',
    'Last_Promotion_Dt',
    'Prom_Reason',
    'promoted_date',
  ];

  @override
  void initState() {
    super.initState();
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
    _verticalScrollController.dispose();
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الموظف من قائمة المرقين')),
      );
    } catch (e) {
      debugPrint(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف الموظف: ${e.toString()}')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);

    await ExcelExporter.exportToExcel(
      context: context,
      data: _promotedData,
      columns: _columns,
      columnNames: PromotionConstants.promotedColumnNames,
      tableName: 'الموظفين_المرقين',
    );

    setState(() => _isLoading = false);
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

    return Stack(
      children: [
        SfDataGridTheme(
          data: SfDataGridThemeData(
            headerColor: Colors.green.shade700,
            gridLineColor: Colors.grey.shade300,
            gridLineStrokeWidth: 1.0,
            selectionColor: Colors.grey.shade400,
            filterIconColor: Colors.white,
            sortIconColor: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SfDataGrid(
              source: _dataSource,
              columnWidthMode: ColumnWidthMode.auto,
              columnWidthCalculationRange: ColumnWidthCalculationRange.allRows,
              allowSorting: true,
              allowFiltering: true,
              selectionMode: SelectionMode.single,
              showHorizontalScrollbar: true,
              showVerticalScrollbar: true,
              isScrollbarAlwaysShown: true,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
              rowHeight: 60,
              headerRowHeight: 65,
              verticalScrollController: _verticalScrollController,
              columns: _buildGridColumns(),
            ),
          ),
        ),
        if (_isLoadingMore) _buildLoadingIndicator(),
      ],
    );
  }

  List<GridColumn> _buildGridColumns() {
    final columns =
        _columns.where((col) => !_hiddenColumns.contains(col)).map((column) {
          double minWidth = 120.0;

          switch (column) {
            case 'Badge_NO':
              minWidth = 100.0;
              break;
            case 'Employee_Name':
              minWidth = 200.0;
              break;
            case 'Grade':
            case 'Status':
              minWidth = 100.0;
              break;
            case 'Adjusted_Eligible_Date':
            case 'Last_Promotion_Dt':
            case 'promoted_date':
              minWidth = 150.0;
              break;
            case 'Prom_Reason':
              minWidth = 200.0;
              break;
          }

          return GridColumn(
            columnName: column,
            minimumWidth: minWidth,
            autoFitPadding: const EdgeInsets.symmetric(horizontal: 16.0),
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

    // Add delete action column
    columns.add(
      GridColumn(
        columnName: 'actions',
        width: 120.0,
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

    final cells =
        row.getCells().map<Widget>((dataGridCell) {
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
