import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/services/promotions_data_service.dart';
import 'package:hr/widgets/promotion_data_grid.dart';
import 'package:hr/widgets/add_employee_dialog.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/date_calculator_dialog.dart';
import 'package:hr/constants/promotion_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class PromotionsScreen extends StatefulWidget {
  final Database? db;
  final String? tableName;

  const PromotionsScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<Map<String, dynamic>> _promotionsData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _hiddenColumns = <String>{};
  int _filteredRecordCount = 0; // Add this

  // Pagination
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _verticalScrollController = ScrollController();

  // Services
  late PromotionsDataService _dataService;

  // Data source for accessing filtered data
  late DataGridSource _dataSource;

  // GlobalKey for accessing the data grid
  GlobalKey<PromotionDataGridState> _promotionDataGridKey =
      GlobalKey<PromotionDataGridState>();

  @override
  void initState() {
    super.initState();
    if (widget.db != null && widget.tableName != null) {
      _dataService = PromotionsDataService(
        db: widget.db!,
        baseTableName: widget.tableName!,
      );
      _initializePromotionsTable();
    } else {
      // Handle the case where db or tableName is null
      setState(() {
        _isLoading = false;
        _errorMessage = 'قاعدة البيانات أو اسم الجدول غير متوفر';
      });
    }
    _verticalScrollController.addListener(_scrollListener);
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = _promotionsData.length;
      });
    });
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

  Future<void> _initializePromotionsTable() async {
    try {
      await _dataService.initializePromotionsTable();
      await _loadData();
    } catch (e) {
      print('Error in _initializePromotionsTable: $e'); // Debug print
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تهيئة قاعدة البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final allColumns = await _dataService.getAvailableColumns();

      // Start with required columns that should be visible by default
      _columns =
          PromotionConstants.requiredColumns
              .where(
                (col) => allColumns.any(
                  (dbCol) =>
                      dbCol.toLowerCase() == col.toLowerCase() ||
                      dbCol.toLowerCase().contains(col.toLowerCase()),
                ),
              )
              .toList();

      if (_columns.isEmpty) {
        _columns =
            allColumns
                .where((col) => col != 'id' && !col.endsWith('_highlighted'))
                .toList();
      }

      if (!_columns.contains('Status')) {
        final gradeIndex = _columns.indexOf('Grade');
        if (gradeIndex != -1) {
          _columns.insert(gradeIndex, 'Status');
        } else {
          _columns.add('Status');
        }
      }

      if (!_columns.contains('Prom_Reason')) {
        final lastPromotionIndex = _columns.indexOf('Last_Promotion_Dt');
        if (lastPromotionIndex != -1) {
          _columns.insert(lastPromotionIndex, 'Prom_Reason');
        } else {
          _columns.add('Prom_Reason');
        }
      }

      final calculatedColumns = [
        'Next_Grade',
        '4% Adj',
        'Annual_Increment',
        'New_Basic',
      ];
      for (final calcCol in calculatedColumns) {
        if (!_columns.contains(calcCol)) {
          _columns.add(calcCol);
        }
      }

      // Add all remaining columns from base sheet (hidden by default)
      final remainingColumns =
          allColumns
              .where(
                (col) =>
                    !_columns.contains(col) &&
                    col != 'id' &&
                    !col.endsWith('_highlighted'),
              )
              .toList();

      // Add remaining columns before actions
      _columns.addAll(remainingColumns);

      // Hide all remaining columns by default
      _hiddenColumns.addAll(remainingColumns);

      _currentPage = 0;
      _hasMoreData = true;
      await _loadMoreData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final data = await _dataService.getPromotionsData(
        limit: PromotionConstants.pageSize,
        offset: _currentPage * PromotionConstants.pageSize,
        columns: _columns,
      );

      print(
        'Loaded ${data.length} records for page $_currentPage',
      ); // Debug print

      setState(() {
        if (_currentPage == 0) {
          _promotionsData = data;
        } else {
          _promotionsData.addAll(data);
        }
        _currentPage++;
        _isLoading = false; // Make sure this is set
        _isLoadingMore = false;
        _hasMoreData = data.length == PromotionConstants.pageSize;
      });
    } catch (e) {
      print('Error in _loadMoreData: $e'); // Debug print
      setState(() {
        _isLoading = false; // Ensure loading is stopped on error
        _isLoadingMore = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _addEmployeesToPromotions(List<String> badgeNumbers) async {
    setState(() => _isLoading = true);

    try {
      final duplicates = await _dataService.addEmployeesToPromotions(
        badgeNumbers,
      );

      // Check which employees were actually found in the base sheet
      final foundEmployees = await _dataService.checkEmployeesInBaseSheet(
        badgeNumbers,
      );
      final notFoundEmployees =
          badgeNumbers
              .where((badge) => !foundEmployees.contains(badge))
              .toList();

      // Reload data to get real-time validation
      _currentPage = 0;
      _hasMoreData = true;
      _promotionsData.clear();
      await _loadMoreData();

      // Calculate successfully added count
      final totalRequestedValid = foundEmployees.length;
      final totalDuplicates = duplicates.length;
      final addedCount = totalRequestedValid - totalDuplicates;

      // Show detailed result message
      String message = '';

      if (addedCount > 0) {
        message += 'تم إضافة $addedCount موظف بنجاح';
      }

      if (duplicates.isNotEmpty) {
        if (message.isNotEmpty) message += '\n\n';
        message +=
            'الأرقام التالية موجودة مسبقاً في قائمة الترقيات:\n${duplicates.join('\n')}';
      }

      if (notFoundEmployees.isNotEmpty) {
        if (message.isNotEmpty) message += '\n\n';
        message +=
            'الأرقام التالية غير موجودة في قاعدة البيانات:\n${notFoundEmployees.join('\n')}';
      }

      if (message.isEmpty) {
        message = 'لم يتم إضافة أي موظف';
      }

      // Show success message (validation issues will be visible as highlighting)
      CustomSnackbar.showSuccess(context, message);
    } catch (e) {
      CustomSnackbar.showError(
        context,
        'خطأ في إضافة الموظفين: ${e.toString()}',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeEmployeeFromPromotions(String badgeNo) async {
    final confirmed = await _showConfirmationDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف الموظف ذو الرقم $badgeNo من قائمة الترقيات؟',
    );

    if (confirmed != true) return;

    try {
      await _dataService.removeEmployeeFromPromotions(badgeNo);

      setState(() {
        _promotionsData.removeWhere((record) {
          final badgeColumn = _columns.firstWhere(
            (col) => col.toLowerCase().contains('badge'),
            orElse: () => 'Badge_NO',
          );
          return record[badgeColumn]?.toString() == badgeNo;
        });
      });

      CustomSnackbar.showSuccess(context, 'تم حذف الموظف من قائمة الترقيات');
    } catch (e) {
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
                child: const Text('تأكيد'),
              ),
            ],
          ),
    );
  }

  void _copyCellContent(String content) {
    CustomSnackbar.showInfo(context, content);
  }

  PromotionDataGrid? _promotionDataGrid; // Keep this field

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);

    // Get filtered data if filters are applied
    final dataToExport = _getFilteredDataForExport();

    await ExcelExporter.exportToExcel(
      context: context,
      data: dataToExport,
      columns: _columns,
      columnNames: PromotionConstants.columnNames,
      tableName:
          dataToExport.length < _promotionsData.length
              ? 'الترقيات_مفلترة'
              : 'الترقيات',
    );

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFilteredDataForExport() {
    // Get filtered data using the GlobalKey
    final state = _promotionDataGridKey.currentState;
    if (state != null) {
      return state.getFilteredDataForExport();
    }
    // Fallback to all data if filtered data is not available
    return _promotionsData;
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder:
          (context) =>
              AddEmployeeDialog(onAddEmployees: _addEmployeesToPromotions),
    );
  }

  void _showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns: _columns,
            columnNames: PromotionConstants.columnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: _refreshDataSource,
          ),
    );
  }

  // Add method to refresh data source with current column visibility
  void _refreshDataSource() {
    setState(() {
      // Force rebuild of the promotion data grid with updated hidden columns
      // Increment a key to force widget recreation
      _promotionDataGridKey = GlobalKey<PromotionDataGridState>();
    });
  }

  Future<void> _updateAdjustedEligibleDate(
    String badgeNo,
    String newDate,
  ) async {
    try {
      await _dataService.updateAdjustedEligibleDate(badgeNo, newDate);

      // Refresh the data to show updated calculations
      _currentPage = 0;
      _hasMoreData = true;
      _promotionsData.clear();
      await _loadMoreData();

      CustomSnackbar.showSuccess(context, 'تم تحديث التاريخ بنجاح');
    } catch (e) {
      CustomSnackbar.showError(
        context,
        'خطأ في تحديث التاريخ: ${e.toString()}',
      );
    }
  }

  void _showDatePickerDialog(String badgeNo, String currentDate) async {
    final result = await DateCalculatorDialog.show(
      context: context,
      currentDate: currentDate,
      title: 'حساب تاريخ الأهلية المعدل',
    );

    if (result != null) {
      await _updateAdjustedEligibleDate(badgeNo, result);
    }
  }

  void _onCellSelected(String cellValue) {
    setState(() {}); // Refresh to show selection changes
  }

  void _copySelectedCells() {
    CustomSnackbar.showInfo(context, 'استخدم Ctrl + النقر لتحديد الخلايا');
  }

  Future<void> _updatePromReason(String badgeNo, String newPromReason) async {
    try {
      await _dataService.updatePromReason(badgeNo, newPromReason);

      // Update the local data without full refresh
      setState(() {
        final badgeColumn = _columns.firstWhere(
          (col) => col.toLowerCase().contains('badge'),
          orElse: () => 'Badge_NO',
        );

        for (final record in _promotionsData) {
          if (record[badgeColumn]?.toString() == badgeNo) {
            record['Prom_Reason'] = newPromReason;
            break;
          }
        }
      });

      CustomSnackbar.showSuccess(
        context,
        newPromReason.isEmpty
            ? 'تم مسح سبب الترقية بنجاح'
            : 'تم تحديث سبب الترقية بنجاح',
      );
    } catch (e) {
      CustomSnackbar.showError(
        context,
        'خطأ في تحديث سبب الترقية: ${e.toString()}',
      );
    }
  }

  Future<void> _promoteEmployee(String badgeNo) async {
    final confirmed = await _showConfirmationDialog(
      'تأكيد الترقية',
      'هل أنت متأكد من ترقية الموظف ذو الرقم $badgeNo؟\nسيتم نقله إلى قائمة الموظفين المرقين.',
    );

    if (confirmed != true) return;

    try {
      await _dataService.promoteEmployee(badgeNo);

      setState(() {
        _promotionsData.removeWhere((record) {
          final badgeColumn = _columns.firstWhere(
            (col) => col.toLowerCase().contains('badge'),
            orElse: () => 'Badge_NO',
          );
          return record[badgeColumn]?.toString() == badgeNo;
        });
      });

      CustomSnackbar.showSuccess(context, 'تم ترقية الموظف بنجاح');
    } catch (e) {
      CustomSnackbar.showError(context, 'خطأ في ترقية الموظف: ${e.toString()}');
    }
  }

  // Add the missing column dragging method
  bool _onColumnDragging(DataGridColumnDragDetails details) {
    if (details.action == DataGridColumnDragAction.dropped &&
        details.to != null) {
      final visibleColumns =
          _columns.where((col) => !_hiddenColumns.contains(col)).toList();

      // Don't allow dragging action columns
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
    }
    return true;
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
              child: _buildActionButtons(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      height: 35,
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _showAddEmployeeDialog,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text(
              'إضافة موظفين',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildContent() {
    if (_promotionsData.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Record count bar
        _buildRecordCountBar(),
        // Data grid
        Expanded(
          child:
              _promotionDataGrid = PromotionDataGrid(
                key: _promotionDataGridKey,
                data: _promotionsData,
                columns: _columns,
                columnNames: PromotionConstants.columnNames,
                hiddenColumns: _hiddenColumns,
                onRemoveEmployee: _removeEmployeeFromPromotions,
                onPromoteEmployee: _promoteEmployee,
                onCopyCellContent: _copyCellContent,
                onUpdateAdjustedDate: _showDatePickerDialog,
                onUpdatePromReason: _updatePromReason,
                onColumnDragging: _onColumnDragging,
                scrollController: _verticalScrollController,
                isLoadingMore: _isLoadingMore,
                onCellSelected: _onCellSelected,
                onFilterChanged: (int filteredCount) {
                  setState(() {
                    _filteredRecordCount = filteredCount;
                  });
                },
              ),
        ),
      ],
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = _promotionsData.length;
    final displayedRecords =
        _filteredRecordCount > 0 ? _filteredRecordCount : totalRecords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
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
                'عرض $displayedRecords من أصل $totalRecords موظف',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              )
            else
              Text(
                'إجمالي الموظفين: $totalRecords',
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد موظفين في قائمة الترقيات',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على "إضافة موظف" لبدء إضافة الموظفين',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
