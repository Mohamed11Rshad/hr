import 'package:flutter/material.dart';
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:hr/screens/base_data_screen.dart';
import 'package:hr/services/terminated_data_service.dart';
import 'package:hr/widgets/terminated/terminated_data_grid.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/common/empty_state.dart';
import 'package:hr/constants/terminated_constants.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/core/app_colors.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TerminatedScreen extends BaseDataScreen {
  final Database? db;
  final String? tableName;

  const TerminatedScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<TerminatedScreen> createState() => _TerminatedScreenState();
}

class _TerminatedScreenState extends BaseDataScreenState<TerminatedScreen> {
  List<Map<String, dynamic>> _terminatedData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _hiddenColumns = <String>{};
  late TerminatedDataService _dataService;

  List<String> _columns = List.from(TerminatedConstants.columns);

  final GlobalKey<TerminatedDataGridState> _terminatedDataGridKey =
      GlobalKey<TerminatedDataGridState>();

  @override
  bool get isLoading => _isLoading;

  @override
  String get errorMessage => _errorMessage;

  @override
  bool get hasData => _terminatedData.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.db != null) {
      _dataService = TerminatedDataService(
        db: widget.db!,
        baseTableName: widget.tableName ?? 'Base_Sheet',
      );
      _initializeAndLoadData();
    }
  }

  Future<void> _initializeAndLoadData() async {
    await _dataService.initializeTerminatedTable();
    await loadData();
  }

  @override
  Future<void> loadData() async {
    if (widget.db == null) return;

    _setLoadingState(true);
    try {
      final data = await _dataService.getTerminatedData();
      setState(() {
        _terminatedData = data;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
        _terminatedData = [];
      });
    } finally {
      _setLoadingState(false);
    }
  }

  void _setLoadingState(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  @override
  Widget buildHeader() {
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
                      onPressed: showColumnVisibilityDialog,
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
                      onPressed:
                          _terminatedData.isNotEmpty ? exportToExcel : null,
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

  @override
  Widget buildEmptyState() {
    return const EmptyState(
      icon: Icons.person_off,
      title: 'لا توجد بيانات مسرحين',
      subtitle: 'لم يتم العثور على أي سجلات مسرحين',
    );
  }

  @override
  Widget buildContent() {
    return Column(
      children: [
        // Record count bar
        _buildRecordCountBar(),
        // Data grid
        Expanded(
          child: TerminatedDataGrid(
            key: _terminatedDataGridKey,
            data: _terminatedData,
            columns: _columns,
            hiddenColumns: _hiddenColumns,
            onRemoveTerminated: _removeTerminated,
            onCopyCellContent: (message) {
              CustomSnackbar.showSuccess(context, message);
            },
            onUpdateDateField: _updateDateField,
            onColumnsReordered: (newColumns) {
              setState(() {
                _columns = newColumns;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = _terminatedData.length;

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
            Text(
              'إجمالي المسرحين: $totalRecords',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns: _columns,
            columnNames: TerminatedConstants.columnNames,
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
      final visibleColumns =
          _columns.where((col) => !_hiddenColumns.contains(col)).toList();

      final visibleData =
          _terminatedData.map((row) {
            final visibleRow = <String, dynamic>{};
            for (final col in visibleColumns) {
              visibleRow[TerminatedConstants.columnNames[col] ?? col] =
                  row[col]?.toString() ?? '';
            }
            return visibleRow;
          }).toList();

      await ExcelExporter.exportToExcel(
        context: context,
        data: visibleData,
        columns: visibleColumns,
        columnNames: TerminatedConstants.columnNames,
        tableName: 'المسرحون',
      );
    } catch (e) {
      CustomSnackbar.showError(
        context,
        'خطأ في تصدير البيانات: ${e.toString()}',
      );
    }
  }

  Future<void> _updateDateField(
    String sNo,
    String fieldName,
    String currentValue,
  ) async {
    DateTime? selectedDate;

    // Parse current value if it exists
    if (currentValue.isNotEmpty) {
      try {
        final parts = currentValue.split('.');
        if (parts.length == 3) {
          selectedDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر التاريخ لـ $fieldName',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );

    if (result != null) {
      final formattedDate =
          '${result.day.toString().padLeft(2, '0')}.${result.month.toString().padLeft(2, '0')}.${result.year}';

      try {
        await _dataService.updateDateField(sNo, fieldName, formattedDate);
        await loadData();
        CustomSnackbar.showSuccess(context, 'تم تحديث $fieldName بنجاح');
      } catch (e) {
        CustomSnackbar.showError(
          context,
          'خطأ في تحديث التاريخ: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _removeTerminated(Map<String, dynamic> record) async {
    final sNo = record['S_NO']?.toString() ?? '';
    final badgeNo = record['Badge_NO']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف سجل الموظف $badgeNo؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _dataService.removeTerminated(sNo);
        await loadData();
        CustomSnackbar.showSuccess(context, 'تم حذف السجل بنجاح');
      } catch (e) {
        CustomSnackbar.showError(context, 'خطأ في حذف السجل: ${e.toString()}');
      }
    }
  }
}
