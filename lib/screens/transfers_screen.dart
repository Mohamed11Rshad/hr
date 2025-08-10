import 'package:flutter/material.dart';
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:hr/screens/base_data_screen.dart';
import 'package:hr/services/transfers_data_service.dart';
import 'package:hr/widgets/transfers/transfers_data_grid.dart';
import 'package:hr/widgets/transfers/add_transfer_dialog.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/common/empty_state.dart';
import 'package:hr/constants/transfers_constants.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TransfersScreen extends BaseDataScreen {
  final Database? db;
  final String? tableName;

  const TransfersScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends BaseDataScreenState<TransfersScreen> {
  List<Map<String, dynamic>> _transfersData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _hiddenColumns = <String>{};
  late TransfersDataService _dataService;
  TransfersDataGrid? _transfersDataGrid; // Add reference
  int _filteredRecordCount = 0; // Add this

  // Add proper column state management like view_data_screen
  List<String> _columns = List.from(TransfersConstants.columns);

  // GlobalKey for accessing the data grid
  final GlobalKey<TransfersDataGridState> _transfersDataGridKey =
      GlobalKey<TransfersDataGridState>();

  @override
  bool get isLoading => _isLoading;

  @override
  String get errorMessage => _errorMessage;

  @override
  bool get hasData => _transfersData.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    if (widget.db != null && widget.tableName != null) {
      _dataService = TransfersDataService(
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
      await _dataService.initializeTransfersTable();
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
      final data = await _dataService.getTransfersData();
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
      _transfersData = data;
      _isLoading = false;
      _errorMessage = '';
    });
  }

  @override
  Widget buildHeader() {
    return buildStandardHeader(
      actions: [
        HeaderAction(
          label: 'إضافة',
          icon: Icons.add,
          onPressed: _showAddTransferDialog,
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
    _transfersDataGrid = TransfersDataGrid(
      key: _transfersDataGridKey,
      data: _transfersData,
      columns: _columns,
      hiddenColumns: _hiddenColumns,
      onRemoveTransfer: _removeTransferRecord,
      onUpdateField: _updateTransferField,
      onCopyCellContent: showInfoMessage,
      onColumnDragging: _onColumnDragging,
      onFilterChanged: (int filteredCount) {
        setState(() {
          _filteredRecordCount = filteredCount;
        });
      },
    );
    return _transfersDataGrid!;
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

      // Add hidden columns first
      for (final column in _columns) {
        if (_hiddenColumns.contains(column)) {
          newColumns.add(column);
        }
      }

      // Add visible columns in new order
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
      icon: Icons.transfer_within_a_station,
      title: 'لا يوجد تنقلات',
      subtitle: 'لم يتم العثور على أي تنقلات في النظام',
    );
  }

  @override
  Future<void> exportToExcel() async {
    _setLoadingState(true);
    try {
      // Get filtered data using the GlobalKey
      final state = _transfersDataGridKey.currentState;
      final dataToExport = state?.getFilteredData() ?? _transfersData;

      await ExcelExporter.exportToExcel(
        context: context,
        data: dataToExport,
        columns: TransfersConstants.columns,
        columnNames: TransfersConstants.columnNames,
        tableName:
            dataToExport.length < _transfersData.length
                ? 'التنقلات_مفلترة'
                : 'التنقلات',
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
            columns: TransfersConstants.columns,
            columnNames: TransfersConstants.columnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: () => setState(() {}),
          ),
    );
  }

  // Transfer-specific methods
  Future<void> _showAddTransferDialog() async {
    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (context) => const AddTransferDialog(),
    );

    if (result != null && result.isNotEmpty) {
      await _addMultipleTransfers(result);
    }
  }

  Future<void> _addMultipleTransfers(
    List<Map<String, String>> transfers,
  ) async {
    _setLoadingState(true);
    try {
      final results = await _dataService.addMultipleTransfers(transfers);

      await loadData(); // Reload the data

      // Show detailed results
      _showTransferResults(results, transfers.length);
    } catch (e) {
      showErrorMessage('خطأ في إضافة التنقلات: ${e.toString()}');
    } finally {
      _setLoadingState(false);
    }
  }

  void _showTransferResults(Map<String, dynamic> results, int totalRequested) {
    final successful = results['successful'] as List<String>;
    final failed = results['failed'] as List<Map<String, String>>;
    final duplicateEmployees = results['duplicateEmployees'] as List<String>;
    final invalidEmployees = results['invalidEmployees'] as List<String>;
    final invalidPositions = results['invalidPositions'] as List<String>;

    String message = '';

    if (successful.isNotEmpty) {
      message += 'تم إضافة ${successful.length} تنقل بنجاح';
    }

    if (duplicateEmployees.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message +=
          'الموظفين التاليين لديهم تنقلات مسبقة:\n${duplicateEmployees.join(', ')}';
    }

    if (invalidEmployees.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message +=
          'أرقام الموظفين التالية غير موجودة:\n${invalidEmployees.join(', ')}';
    }

    if (invalidPositions.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message +=
          'أكواد الوظائف التالية غير موجودة:\n${invalidPositions.join(', ')}';
    }

    if (failed.isNotEmpty) {
      if (message.isNotEmpty) message += '\n\n';
      message += 'فشل في إضافة التنقلات التالية:\n';
      for (final failure in failed) {
        message +=
            '${failure['badgeNo']} -> ${failure['positionCode']}: ${failure['reason']}\n';
      }
    }

    if (message.isEmpty) {
      message = 'لم يتم إضافة أي تنقل';
    }

    // Show success or warning based on results
    if (successful.length == totalRequested) {
      showSuccessMessage(message);
    } else if (successful.isNotEmpty) {
      showInfoMessage(message); // Partial success
    } else {
      showErrorMessage(message); // Complete failure
    }
  }

  Future<void> _removeTransferRecord(Map<String, dynamic> record) async {
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final sNo = record['S_NO']?.toString() ?? '';

    final confirmed = await _showConfirmationDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف التنقل للموظف ذو الرقم $badgeNo؟',
    );

    if (confirmed != true) return;

    try {
      await _dataService.removeTransfer(sNo);
      _removeTransferFromList(sNo);
      showSuccessMessage('تم الحذف بنجاح');
    } catch (e) {
      showErrorMessage('خطأ في الحذف: ${e.toString()}');
    }
  }

  void _removeTransferFromList(String sNo) {
    setState(() {
      _transfersData.removeWhere((item) => item['S_NO']?.toString() == sNo);
    });

    // Force refresh the data grid by recreating it with new data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _transfersDataGridKey.currentState;
      state?.refreshDataSource();
    });
  }

  Future<void> _updateTransferField(
    String sNo,
    String fieldName,
    String value,
  ) async {
    try {
      await _dataService.updateTransferField(sNo, fieldName, value);

      // If this is a "Done" operation, remove the record from the list
      if (fieldName == 'DONE_YES_NO' && value.toLowerCase() == 'done') {
        _removeTransferFromList(sNo);
        showSuccessMessage('تم نقل الموظف بنجاح');
      } else {
        _updateTransferInList(sNo, fieldName, value);
        showSuccessMessage('تم التحديث بنجاح');
      }
    } catch (e) {
      showErrorMessage('خطأ في التحديث: ${e.toString()}');
    }
  }

  void _updateTransferInList(String sNo, String fieldName, String value) {
    setState(() {
      for (final record in _transfersData) {
        if (record['S_NO']?.toString() == sNo) {
          record[fieldName] = value;
          break;
        }
      }
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
