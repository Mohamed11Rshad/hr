import 'package:flutter/material.dart';
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:hr/screens/base_data_screen.dart';
import 'package:hr/services/termination_data_service.dart';
import 'package:hr/services/terminated_data_service.dart';
import 'package:hr/widgets/termination/termination_data_grid.dart';
import 'package:hr/widgets/termination/add_termination_dialog.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/common/empty_state.dart';
import 'package:hr/constants/termination_constants.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TerminationScreen extends BaseDataScreen {
  final Database? db;
  final String? tableName;

  const TerminationScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<TerminationScreen> createState() => _TerminationScreenState();
}

class _TerminationScreenState extends BaseDataScreenState<TerminationScreen> {
  List<Map<String, dynamic>> _terminationData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _hiddenColumns = <String>{};
  late TerminationDataService _dataService;
  late TerminatedDataService _terminatedDataService; // Add this
  TerminationDataGrid? _terminationDataGrid;

  List<String> _columns = List.from(TerminationConstants.columns);

  // GlobalKey for accessing the data grid
  final GlobalKey<TerminationDataGridState> _terminationDataGridKey =
      GlobalKey<TerminationDataGridState>();

  @override
  bool get isLoading => _isLoading;

  @override
  String get errorMessage => _errorMessage;

  @override
  bool get hasData => _terminationData.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    if (widget.db != null && widget.tableName != null) {
      _dataService = TerminationDataService(
        db: widget.db!,
        baseTableName: widget.tableName!,
      );
      _terminatedDataService = TerminatedDataService(
        db: widget.db!,
        baseTableName: widget.tableName!,
      );
      _initializeAndLoadData();
    } else {
      _setError('قاعدة البيانات أو اسم الجدول غير متوفر');
    }
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await _dataService.initializeTerminationTable();
      await _terminatedDataService.initializeTerminatedTable();
      await loadData();
    } catch (e) {
      _setError('خطأ في تهيئة قاعدة البيانات: ${e.toString()}');
    }
  }

  void _setError(String error) {
    setState(() {
      _isLoading = false;
      _errorMessage = error;
    });
  }

  @override
  Future<void> loadData() async {
    try {
      _setLoadingState(true);
      final data = await _dataService.getTerminationsData();
      _setDataState(data);
    } catch (e) {
      _setError('خطأ في تحميل البيانات: ${e.toString()}');
    }
  }

  void _setLoadingState(bool loading) {
    setState(() {
      _isLoading = loading;
      if (loading) _errorMessage = '';
    });
  }

  void _setDataState(List<Map<String, dynamic>> data) {
    setState(() {
      _terminationData = data;
      _isLoading = false;
      _errorMessage = '';
    });
  }

  @override
  Widget buildHeader() {
    return buildStandardHeader(
      showAddButton: false,
      actions: [
        HeaderAction(
          label: 'إضافة موظف',
          icon: Icons.person_add,
          onPressed: _showAddTerminationDialog,
          color: Colors.green,
        ),
        HeaderAction(
          label: 'إظهار/إخفاء الأعمدة',
          icon: Icons.visibility,
          onPressed: showColumnVisibilityDialog,
        ),
        HeaderAction(
          label: 'إستخراج بصيغة Excel',
          icon: Icons.file_download,
          onPressed: exportToExcel,
        ),
      ],
    );
  }

  @override
  Widget buildContent() {
    _terminationDataGrid = TerminationDataGrid(
      key: _terminationDataGridKey,
      data: _terminationData,
      columns: _columns,
      hiddenColumns: _hiddenColumns,
      onRemoveTermination: _removeTerminationRecord,
      onCopyCellContent: showInfoMessage,
      onColumnDragging: _onColumnDragging,
      onUpdateAppraisalText: _updateAppraisalText,
      onTransferToTerminated: _transferToTerminated,
      onFilterChanged: (int filteredCount) {
        // Handle filtered count if needed
      },
    );
    return _terminationDataGrid!;
  }

  // Add method to update appraisal text
  Future<void> _updateAppraisalText(String sNo, String currentValue) async {
    // Define appraisal options
    const appraisalOptions = [
      {'value': 'O', 'label': 'O'},
      {'value': 'E', 'label': 'E'},
      {'value': 'Ep', 'label': 'Ep'},
      {'value': 'M', 'label': 'M'},
      {'value': 'P', 'label': 'P'},
    ];

    String selectedValue = currentValue.isNotEmpty ? currentValue : '';

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تعديل نص التقييم'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedValue.isNotEmpty ? selectedValue : null,
                  decoration: const InputDecoration(
                    labelText: 'نص التقييم',
                    border: OutlineInputBorder(),
                    hintText: 'اختر نص التقييم...',
                  ),
                  items:
                      appraisalOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option['value'],
                          child: Text(option['label']!),
                        );
                      }).toList(),
                  onChanged: (value) {
                    selectedValue = value ?? '';
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(selectedValue),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        await _dataService.updateAppraisalText(sNo, result);

        // Reload all data to recalculate dependent fields
        await loadData();

        showSuccessMessage('تم تحديث نص التقييم بنجاح');
      } catch (e) {
        showErrorMessage('خطأ في تحديث نص التقييم: ${e.toString()}');
      }
    }
  }

  bool _onColumnDragging(DataGridColumnDragDetails details) {
    if (details.action == DataGridColumnDragAction.dropped &&
        details.to != null) {
      final visibleColumns =
          _columns.where((col) => !_hiddenColumns.contains(col)).toList();

      if (details.from >= visibleColumns.length) return true;

      final rearrangedColumn = visibleColumns[details.from];
      visibleColumns.removeAt(details.from);
      visibleColumns.insert(details.to!, rearrangedColumn);

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
  Widget buildEmptyState() {
    return const EmptyState(
      icon: Icons.person_remove,
      title: 'لا يوجد موظفين في القائمة',
      subtitle: 'اضغط على "إضافة موظف" لبدء إضافة الموظفين',
    );
  }

  @override
  Future<void> exportToExcel() async {
    _setLoadingState(true);
    try {
      // Get filtered data using the GlobalKey
      final state = _terminationDataGridKey.currentState;
      final dataToExport = state?.getFilteredData() ?? _terminationData;

      await ExcelExporter.exportToExcel(
        context: context,
        data: dataToExport,
        columns: TerminationConstants.columns,
        columnNames: TerminationConstants.columnNames,
        tableName:
            dataToExport.length < _terminationData.length
                ? 'التسريحات_مفلترة'
                : 'التسريحات',
      );
      showSuccessMessage('تم تصدير البيانات بنجاح');
    } catch (e) {
      showErrorMessage('خطأ في تصدير البيانات: ${e.toString()}');
    } finally {
      _setLoadingState(false);
    }
  }

  @override
  void showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns: TerminationConstants.columns,
            columnNames: TerminationConstants.columnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: _refreshDataSource,
          ),
    );
  }

  // Add method to refresh data source with current column visibility
  void _refreshDataSource() {
    setState(() {
      // Force rebuild of the data grid with updated hidden columns
    });
  }

  Future<void> _showAddTerminationDialog() async {
    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (context) => const AddTerminationDialog(),
    );

    if (result != null && result.isNotEmpty) {
      await _addMultipleTerminations(result);
    }
  }

  Future<void> _addMultipleTerminations(
    List<Map<String, String>> terminations,
  ) async {
    _setLoadingState(true);
    try {
      final results = await _dataService.addMultipleTerminations(terminations);

      await loadData();

      _showTerminationResults(results, terminations.length);
    } catch (e) {
      showErrorMessage('خطأ في إضافة التسريحات: ${e.toString()}');
    } finally {
      _setLoadingState(false);
    }
  }

  void _showTerminationResults(
    Map<String, dynamic> results,
    int totalRequested,
  ) {
    final successful = results['successful'] as List<String>;
    final failed = results['failed'] as List<Map<String, String>>;
    final duplicateEmployees = results['duplicateEmployees'] as List<String>;
    final invalidEmployees = results['invalidEmployees'] as List<String>;

    String message = '';

    if (successful.isNotEmpty) {
      message += 'تم إضافة ${successful.length} تسريح بنجاح';
    }

    if (duplicateEmployees.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message +=
          'الموظفين التاليين لديهم تسريحات مسبقة:\n${duplicateEmployees.join(', ')}';
    }

    if (invalidEmployees.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message +=
          'أرقام الموظفين التالية غير موجودة:\n${invalidEmployees.join(', ')}';
    }

    if (failed.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message += 'فشل في إضافة التسريحات التالية:\n';
      for (final failure in failed) {
        message += '${failure['badgeNo']}: ${failure['reason']}\n';
      }
    }

    if (message.isEmpty) {
      message = 'لم يتم إضافة أي تسريح';
    }

    if (successful.length == totalRequested) {
      showSuccessMessage(message);
    } else if (successful.isNotEmpty) {
      showInfoMessage(message);
    } else {
      showErrorMessage(message);
    }
  }

  Future<void> _removeTerminationRecord(Map<String, dynamic> record) async {
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final sNo = record['S_NO']?.toString() ?? '';

    final confirmed = await _showConfirmationDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف التسريح للموظف ذو الرقم $badgeNo؟',
    );

    if (confirmed != true) return;

    try {
      await _dataService.removeTermination(sNo);
      _removeTerminationFromList(sNo);
      showSuccessMessage('تم الحذف بنجاح');
    } catch (e) {
      showErrorMessage('خطأ في الحذف: ${e.toString()}');
    }
  }

  Future<void> _transferToTerminated(Map<String, dynamic> record) async {
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final employeeName = record['Employee_Name']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد النقل'),
            content: Text(
              'هل تريد نقل الموظف $employeeName ($badgeNo) إلى قائمة المسرحين؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('نقل'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final sNo = record['S_NO']?.toString() ?? '';
        await _terminatedDataService.transferFromTermination(record);
        await _dataService.removeTermination(sNo);
        await loadData();
        showSuccessMessage('تم نقل الموظف إلى قائمة المسرحين بنجاح');
      } catch (e) {
        showErrorMessage('خطأ في نقل الموظف: ${e.toString()}');
      }
    }
  }

  void _removeTerminationFromList(String sNo) {
    setState(() {
      _terminationData.removeWhere((item) => item['S_NO']?.toString() == sNo);
    });

    // Force refresh the data grid by recreating it with new data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _terminationDataGridKey.currentState;
      state?.refreshDataSource();
    });
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
}
