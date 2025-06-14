import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/services/transfers_data_service.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
import 'package:hr/widgets/transfers/transfers_data_grid.dart';
import 'package:hr/widgets/transfers/add_transfer_dialog.dart';
import 'package:hr/constants/transfers_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TransfersScreen extends StatefulWidget {
  final Database? db;
  final String? tableName;

  const TransfersScreen({Key? key, required this.db, this.tableName})
    : super(key: key);

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  List<Map<String, dynamic>> _transfersData = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<String> _hiddenColumns = <String>{};

  late TransfersDataService _dataService;

  @override
  void initState() {
    super.initState();
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
  }

  Future<void> _initializeAndLoadData() async {
    try {
      await _dataService.initializeTransfersTable();
      await _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تهيئة قاعدة البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final data = await _dataService.getTransfersData();
      setState(() {
        _transfersData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _showAddTransferDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const AddTransferDialog(),
    );

    if (result != null) {
      await _addTransfer(result['badgeNo']!, result['positionCode']!);
    }
  }

  Future<void> _addTransfer(String badgeNo, String positionCode) async {
    setState(() => _isLoading = true);

    try {
      await _dataService.addTransfer(badgeNo, positionCode);
      await _loadData();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الإضافة بنجاح')));
    } catch (e) {
      String errorMessage = 'خطأ في الإضافة: ${e.toString()}';

      // Provide specific error messages
      if (e.toString().contains('not found in base sheet')) {
        errorMessage =
            'رقم الموظف $badgeNo غير موجود في قاعدة البيانات الأساسية';
      } else if (e.toString().contains('not found in Staff Assignments')) {
        errorMessage = 'كود الوظيفة $positionCode غير موجود في جدول التوزيعات';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
      setState(() {
        _transfersData.removeWhere((item) => item['S_NO']?.toString() == sNo);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: ${e.toString()}')));
    }
  }

  Future<void> _updateTransferField(
    String sNo,
    String fieldName,
    String value,
  ) async {
    try {
      await _dataService.updateTransferField(sNo, fieldName, value);

      setState(() {
        for (final record in _transfersData) {
          if (record['S_NO']?.toString() == sNo) {
            record[fieldName] = value;
            break;
          }
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم التحديث بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التحديث: ${e.toString()}')),
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

  void _showColumnVisibilityDialog() {
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

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);

    await ExcelExporter.exportToExcel(
      context: context,
      data: _transfersData,
      columns: TransfersConstants.columns,
      columnNames: TransfersConstants.columnNames,
      tableName: 'التنقلات',
    );

    setState(() => _isLoading = false);
  }

  void _copyCellContent(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content), duration: const Duration(seconds: 2)),
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
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showAddTransferDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة', style: TextStyle(color: Colors.white)),
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
      ),
    );
  }

  Widget _buildContent() {
    if (_transfersData.isEmpty) {
      return _buildEmptyState();
    }

    return TransfersDataGrid(
      data: _transfersData,
      hiddenColumns: _hiddenColumns,
      onRemoveTransfer: _removeTransferRecord,
      onUpdateField: _updateTransferField,
      onCopyCellContent: _copyCellContent,
    );
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
            'لا توجد تنقلات',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على "إضافة" لبدء إضافة التنقلات',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
