import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/services/database_service.dart';
import 'package:hr/services/excel_services.dart';
import 'package:hr/services/file_picker_service.dart';
import 'package:hr/services/config_sheet_service.dart';
import 'package:hr/widgets/main_upload_card.dart';
import 'package:hr/promotions_screen.dart';
import 'package:hr/view_data_screen.dart';
import 'package:hr/view_latest_data_screen.dart';
import 'package:hr/promoted_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});

  @override
  State<AddDataScreen> createState() => _AddDataScreenState();
}

class _AddDataScreenState extends State<AddDataScreen> {
  String _status = 'جاهز لرفع ملف Excel';
  bool _isLoading = false;
  bool _salaryScaleAExists = false;
  bool _salaryScaleBExists = false;
  bool _annualIncreaseAExists = false;
  bool _annualIncreaseBExists = false;
  bool _statusExists = false;
  final FilePickerService _filePicker = FilePickerService();
  late ConfigSheetService _configSheetService;
  Database? _db;
  int _selectedIndex = 0;
  String? _latestTable;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    _db = await DatabaseService.openDatabase();
    _configSheetService = ConfigSheetService(_db!);
    await _updateLatestTable();
    await _checkConfigTables();
  }

  Future<void> _updateLatestTable() async {
    if (_db != null) {
      final tables = await DatabaseService.getAvailableTables(_db!);
      if (tables.isNotEmpty) {
        _latestTable = tables.last;
      } else {
        _latestTable = null;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = [
      'إضافة بيانات',
      'سجل المتغيرات',
      'عرض أحدث البيانات',
      'الترقيات',
      'تم ترقيتهم',
    ];
    return AppBar(
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
      title: Text(
        titles[_selectedIndex],
        style: TextStyle(
          fontSize: 18.sp.clamp(16, 22),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 48),
          _buildDrawerItem(0, 'إضافة بيانات', true),
          const SizedBox(height: 12),
          _buildDrawerItem(1, 'عرض البيانات', true),
          const SizedBox(height: 12),
          _buildDrawerItem(2, 'عرض أحدث البيانات', true),
          const SizedBox(height: 12),
          _buildDrawerItem(3, 'الترقيات', _canAccessPromotions()),
          const SizedBox(height: 12),
          _buildDrawerItem(4, 'تم ترقيتهم', true),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, bool enabled) {
    return ListTile(
      title: Text(title),
      selected: _selectedIndex == index,
      selectedColor: AppColors.primaryColor,
      titleTextStyle: TextStyle(fontSize: 16.sp.clamp(16, 22)),
      textColor: enabled ? Colors.black : Colors.grey,
      selectedTileColor: AppColors.primaryColor.withAlpha(40),
      onTap: () {
        if (enabled) {
          _onItemTapped(index);
          Navigator.pop(context);
        } else {
          _showPromotionsAccessMessage();
          Navigator.pop(context);
        }
      },
    );
  }

  bool _canAccessPromotions() {
    return _salaryScaleAExists &&
        _salaryScaleBExists &&
        _annualIncreaseAExists &&
        _annualIncreaseBExists &&
        _statusExists;
  }

  void _showPromotionsAccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'يجب رفع جميع شيتات حساب الزيادة وشيت الحالة أولاً قبل الوصول إلى شاشة الترقيات',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildAddDataScreen();
      case 1:
        return ViewDataScreen(db: _db);
      case 2:
        return ViewLatestDataScreen(db: _db, tableName: "Base_Sheet");
      case 3:
        return PromotionsScreen(db: _db, tableName: "Base_Sheet");
      case 4:
        return PromotedScreen(db: _db, tableName: "Base_Sheet");
      default:
        return _buildAddDataScreen();
    }
  }

  Widget _buildAddDataScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 128),
        child: MainUploadCard(
          status: _status,
          isLoading: _isLoading,
          salaryScaleAExists: _salaryScaleAExists,
          salaryScaleBExists: _salaryScaleBExists,
          annualIncreaseAExists: _annualIncreaseAExists,
          annualIncreaseBExists: _annualIncreaseBExists,
          statusExists: _statusExists,
          onMainUpload: _processExcelFile,
          onConfigUpload: _processConfigSheet,
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _processExcelFile() async {
    if (_db == null) return;

    setState(() {
      _isLoading = true;
      _status = 'جاري تحميل ملف Excel...';
    });

    try {
      final file = await _filePicker.pickExcelFile();
      if (file != null) {
        setState(() => _status = 'جاري معالجة الملف...');
        final excelService = ExcelService(_db!);
        final result = await excelService.processExcelFile(file);

        setState(() => _status = result);
        await _updateLatestTable();
      } else {
        setState(() => _status = 'لم يتم اختيار ملف');
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('duplicate column name')) {
        final duplicatedColumns = _findDuplicatedColumns(null);
        if (duplicatedColumns.isNotEmpty) {
          setState(
            () =>
                _status = 'خطأ: الأعمدة  ${duplicatedColumns.join(', ')} مكررة',
          );
        } else {
          setState(() => _status = 'خطأ: يوجد أعمدة مكررة في الملف');
        }
      } else {
        setState(() => _status = 'خطأ في معالجة الملف: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<String> _findDuplicatedColumns(File? file) {
    if (file == null) return [];

    try {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      for (var sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;
        final rows = sheet.rows;
        if (rows.isEmpty) continue;

        // Get header row
        final headerRow = rows[0];
        final headers = <String>[];
        final duplicates = <String>{};

        // Find duplicates
        for (var cell in headerRow) {
          final header = cell?.value.toString().trim() ?? '';
          if (header.isEmpty) continue;

          if (headers.contains(header)) {
            duplicates.add(header);
          } else {
            headers.add(header);
          }
        }

        return duplicates.toList();
      }
    } catch (e) {
      debugPrint('Error finding duplicates: $e');
    }

    return [];
  }

  Future<void> _processConfigSheet(String sheetName) async {
    if (_db == null) return;

    setState(() {
      _isLoading = true;
      _status = 'جاري تحميل ملف Excel...';
    });

    try {
      final file = await _filePicker.pickExcelFile();
      if (file != null) {
        setState(() => _status = 'جاري معالجة الملف...');

        final result = await _configSheetService.processConfigSheet(
          file,
          sheetName,
        );

        setState(() => _status = result);
        await _checkConfigTables();
      } else {
        setState(() => _status = 'لم يتم اختيار ملف');
      }
    } catch (e) {
      setState(() => _status = 'خطأ في معالجة الملف: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConfigTables() async {
    if (_db == null) return;

    final tables = await DatabaseService.getAvailableTables(_db!);

    setState(() {
      _salaryScaleAExists = tables.contains('Salary_Scale_A');
      _salaryScaleBExists = tables.contains('Salary_Scale_B');
      _annualIncreaseAExists = tables.contains('Annual_Increase_A');
      _annualIncreaseBExists = tables.contains('Annual_Increase_B');
      _statusExists = tables.contains('Status');
    });
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}
