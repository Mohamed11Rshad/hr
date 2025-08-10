import 'package:flutter/material.dart';
import 'package:hr/screens/base_data_screen.dart';
import 'package:hr/services/appraisal_data_service.dart';
import 'package:hr/widgets/appraisal/appraisal_data_grid.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/common/empty_state.dart';
import 'package:hr/constants/appraisal_constants.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class AppraisalScreen extends BaseDataScreen {
  final Database? db;
  final String? tableName;

  const AppraisalScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<AppraisalScreen> createState() => _AppraisalScreenState();
}

class _AppraisalScreenState extends BaseDataScreenState<AppraisalScreen> {
  List<Map<String, dynamic>> _appraisalData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _hiddenColumns = <String>{};
  late AppraisalDataService _dataService;
  int _filteredRecordCount = 0;
  final Map<String, Map<String, dynamic>> _changedRecords = {};

  List<String> _columns = List.from(AppraisalConstants.columns);

  // GlobalKey for accessing the data grid
  final GlobalKey<AppraisalDataGridState> _appraisalDataGridKey =
      GlobalKey<AppraisalDataGridState>();

  @override
  bool get isLoading => _isLoading;

  @override
  String get errorMessage => _errorMessage;

  @override
  bool get hasData => _appraisalData.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    if (widget.db != null && widget.tableName != null) {
      _dataService = AppraisalDataService(
        db: widget.db!,
        baseTableName: widget.tableName!,
      );
      loadData();
    } else {
      _setError('قاعدة البيانات أو اسم الجدول غير متوفر');
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
      final data = await _dataService.getAppraisalData();
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
      _appraisalData = data;
      _isLoading = false;
      _errorMessage = '';
      _filteredRecordCount = data.length;
    });
  }

  @override
  Widget buildHeader() {
    return buildStandardHeader(
      showAddButton: false, // Hide add button
      actions: [
        HeaderAction(
          label: 'إخفاء/إظهار الأعمدة',
          icon: Icons.view_column,
          onPressed: showColumnVisibilityDialog,
          color: Colors.blue.shade600,
        ),
        HeaderAction(
          label: 'تصدير إلى Excel',
          icon: Icons.download,
          onPressed: exportToExcel,
          color: Colors.green.shade600,
        ),
      ],
    );
  }

  @override
  Widget buildContent() {
    return AppraisalDataGrid(
      key: _appraisalDataGridKey,
      data: _appraisalData,
      columns: _columns,
      hiddenColumns: _hiddenColumns,
      onCopyCellContent: showInfoMessage,
      onColumnDragging: _onColumnDragging,
      onFilterChanged: (int filteredCount) {
        setState(() {
          _filteredRecordCount = filteredCount;
        });
      },
      onCellValueChanged: _onCellValueChanged,
    );
  }

  bool _onColumnDragging(DataGridColumnDragDetails details) {
    if (details.action == DataGridColumnDragAction.dropped &&
        details.to != null) {
      final visibleColumns =
          _columns.where((col) => !_hiddenColumns.contains(col)).toList();

      // Ensure the indices are valid
      if (details.from >= visibleColumns.length ||
          details.to! >= visibleColumns.length) {
        return true;
      }

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

  Future<void> _onCellValueChanged(
    int rowIndex,
    String columnName,
    String newValue,
  ) async {
    try {
      if (columnName == 'Grade') {
        final record = _appraisalData[rowIndex];
        final badgeNo = record['Badge_NO']?.toString() ?? '';
        if (badgeNo.isEmpty) return;

        // Validate grade value
        final cleanedGrade = newValue.trim();
        if (cleanedGrade.isEmpty) {
          showErrorMessage('لا يمكن أن يكون Grade فارغًا');
          return;
        }

        // Save the grade change
        await _dataService.saveGradeChange(
          badgeNo,
          cleanedGrade,
          record['New_Basic_System']?.toString() ?? '',
        );

        // Recalculate values for the new grade
        final updatedRecord = await _dataService.recalculateForGrade(
          record,
          newValue,
        );

        setState(() {
          _appraisalData[rowIndex] = updatedRecord;
          _changedRecords[badgeNo] = updatedRecord;
        });

        // Refresh the grid
        _appraisalDataGridKey.currentState?.refresh();

        showSuccessMessage('تم تحديث Grade بنجاح');
      } else if (columnName == 'New_Basic_System') {
        final record = _appraisalData[rowIndex];
        final badgeNo = record['Badge_NO']?.toString() ?? '';
        if (badgeNo.isEmpty) return;

        // Clean and validate the new basic system value
        final cleanedNewBasic = newValue.trim();

        // Save the New_Basic_System value along with the current grade
        await _dataService.saveGradeChange(
          badgeNo,
          record['Grade']?.toString() ?? '',
          cleanedNewBasic,
        );

        setState(() {
          record['New_Basic_System'] = newValue;
          _changedRecords[badgeNo] = record;
        });

        showSuccessMessage('تم حفظ القيمة الجديدة بنجاح');
      }
    } catch (e) {
      showErrorMessage('خطأ في التحديث: ${e.toString()}');
      print('Error updating cell value: $e');
    }
  }

  // Method to get filtered data for export
  List<Map<String, dynamic>> _getFilteredDataForExport() {
    final state = _appraisalDataGridKey.currentState;
    return state?.getFilteredData() ?? _appraisalData;
  }

  @override
  void showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns: _columns,
            columnNames: AppraisalConstants.columnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: () {
              setState(() {});
            },
          ),
    );
  }

  @override
  Future<void> exportToExcel() async {
    try {
      showInfoMessage('جاري التصدير...');

      // Get filtered data for export
      final dataToExport = _getFilteredDataForExport();

      await ExcelExporter.exportToExcel(
        context: context,
        data: dataToExport,
        columns:
            _columns.where((col) => !_hiddenColumns.contains(col)).toList(),
        columnNames: AppraisalConstants.columnNames,
        tableName: 'appraisal_data',
      );

      showSuccessMessage('تم التصدير بنجاح');
    } catch (e) {
      showErrorMessage('خطأ في التصدير: ${e.toString()}');
    }
  }

  @override
  Widget buildEmptyState() {
    return const EmptyState(
      icon: Icons.assessment,
      title: 'لا توجد بيانات تقييم',
    );
  }
}
