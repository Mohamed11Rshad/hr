import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/services/promotions_data_service.dart';
import 'package:hr/widgets/promotion_data_grid.dart';
import 'package:hr/widgets/add_employee_dialog.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/custom_date_picker_dialog.dart';
import 'package:hr/constants/promotion_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  // Pagination
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _verticalScrollController = ScrollController();

  // Services
  late PromotionsDataService _dataService;

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
      final errorsAndDuplicates = await _dataService.addEmployeesToPromotions(
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

      // Separate validation errors from duplicates
      final validationErrors =
          errorsAndDuplicates
              .where(
                (error) =>
                    error.contains('Old Basic') || error.contains('Grade'),
              )
              .toList();
      final duplicates =
          errorsAndDuplicates
              .where(
                (error) =>
                    !error.contains('Old Basic') && !error.contains('Grade'),
              )
              .where((badge) => foundEmployees.contains(badge))
              .toList();

      // Reload data
      _currentPage = 0;
      _hasMoreData = true;
      _promotionsData.clear();
      await _loadMoreData();

      // Calculate successfully added count
      final totalRequestedValid = foundEmployees.length;
      final totalErrors = duplicates.length + validationErrors.length;
      final addedCount = totalRequestedValid - totalErrors;

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

      if (validationErrors.isNotEmpty) {
        if (message.isNotEmpty) message += '\n\n';
        message += 'أخطاء في البيانات:\n${validationErrors.join('\n')}';
      }

      if (notFoundEmployees.isNotEmpty) {
        if (message.isNotEmpty) message += '\n\n';
        message +=
            'الأرقام التالية غير موجودة في قاعدة البيانات:\n${notFoundEmployees.join('\n')}';
      }

      if (message.isEmpty) {
        message = 'لم يتم إضافة أي موظف';
      }

      // Show message with appropriate styling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SingleChildScrollView(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
          duration: Duration(seconds: validationErrors.isNotEmpty ? 8 : 5),
          backgroundColor: validationErrors.isNotEmpty ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إضافة الموظفين: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الموظف من قائمة الترقيات')),
      );
    } catch (e) {
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
                child: const Text('تأكيد'),
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
      data: _promotionsData,
      columns: _columns,
      columnNames: PromotionConstants.columnNames,
      tableName: 'الترقيات',
    );

    setState(() => _isLoading = false);
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
            onVisibilityChanged: () => setState(() {}),
          ),
    );
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث التاريخ بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث التاريخ: ${e.toString()}')),
      );
    }
  }

  void _showDatePickerDialog(String badgeNo, String currentDate) async {
    final result = await CustomDatePickerDialog.show(
      context: context,
      currentDate: currentDate,
      title: 'تعديل التاريخ',
    );

    if (result != null) {
      await _updateAdjustedEligibleDate(badgeNo, result);
    }
  }

  void _onCellSelected(String cellValue) {
    setState(() {}); // Refresh to show selection changes
  }

  void _copySelectedCells() {
    // Get the data source from the grid
    final promotionDataGrid = _buildContent() as PromotionDataGrid;
    // We need to access the data source, but since it's created inside the grid,
    // we'll implement this differently by adding methods to PromotionDataGrid
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('استخدم Ctrl + النقر لتحديد الخلايا'),
        duration: Duration(seconds: 2),
      ),
    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newPromReason.isEmpty
                ? 'تم مسح سبب الترقية بنجاح'
                : 'تم تحديث سبب الترقية بنجاح',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث سبب الترقية: ${e.toString()}')),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم ترقية الموظف بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في ترقية الموظف: ${e.toString()}')),
      );
    }
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

    return PromotionDataGrid(
      data: _promotionsData,
      columns: _columns,
      columnNames: PromotionConstants.columnNames,
      hiddenColumns: _hiddenColumns,
      onRemoveEmployee: _removeEmployeeFromPromotions,
      onPromoteEmployee: _promoteEmployee,
      onCopyCellContent: _copyCellContent,
      onUpdateAdjustedDate: _showDatePickerDialog,
      onUpdatePromReason: _updatePromReason,
      scrollController: _verticalScrollController,
      isLoadingMore: _isLoadingMore,
      onCellSelected: _onCellSelected,
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
