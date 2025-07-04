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
import 'package:hr/transfers_screen.dart';
import 'package:hr/edit_data_screen.dart';
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
  bool _staffAssignmentsExists = false; // Add new property
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
    try {
      setState(() {
        _status = 'جاري تهيئة قاعدة البيانات...';
      });

      _db = await DatabaseService.openDatabase();

      // Verify database is working
      final testQuery = await _db!.rawQuery('SELECT 1 as test');
      print('Database test query result: $testQuery');

      _configSheetService = ConfigSheetService(_db!);
      await _updateLatestTable();
      await _checkConfigTables();

      setState(() {
        _status = 'جاهز لرفع ملف Excel';
      });

      print('Database initialization completed successfully');
    } catch (e) {
      print('Database initialization error: $e');
      setState(() {
        _status = 'خطأ في تهيئة قاعدة البيانات: ${e.toString()}';
      });

      // Try alternative initialization
      try {
        if (Platform.isWindows || Platform.isLinux) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
        _db = await DatabaseService.openDatabase();
        _configSheetService = ConfigSheetService(_db!);
        await _updateLatestTable();
        await _checkConfigTables();

        setState(() {
          _status = 'جاهز لرفع ملف Excel (تم الاستعادة)';
        });
      } catch (retryError) {
        print('Retry failed: $retryError');
        setState(() {
          _status = 'فشل في تهيئة قاعدة البيانات';
        });
      }
    }
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
      'عرض البيانات',
      'عرض أحدث البيانات',
      'الترقيات',
      'تم ترقيتهم',
      'التنقلات',
      'تعديل البيانات', // Add new title
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
          const SizedBox(height: 12),
          _buildDrawerItem(5, 'التنقلات', _staffAssignmentsExists),
          const SizedBox(height: 12),
          _buildDrawerItem(6, 'تعديل البيانات', true), // Add new menu item
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
          _showAccessMessage(index);
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

  void _showAccessMessage(int index) {
    String message = '';
    if (index == 3) {
      message =
          'يجب رفع جميع شيتات حساب الزيادة وشيت الحالة أولاً قبل الوصول إلى شاشة الترقيات';
    } else if (index == 5) {
      message =
          'يجب رفع شيت Staff Assignments أولاً قبل الوصول إلى شاشة التنقلات';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
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
      case 5:
        return TransfersScreen(db: _db, tableName: "Base_Sheet");
      case 6:
        return EditDataScreen(db: _db); // Add new screen
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
          staffAssignmentsExists:
              _staffAssignmentsExists, // Add staff assignments status
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
      _status = 'جاري اختيار الملف...';
    });

    try {
      final file = await _filePicker.pickExcelFile();
      if (file != null) {
        // Show file selected and start processing
        setState(() => _status = 'تم اختيار الملف، جاري التحليل...');

        // Add a small delay to allow UI to update
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Process file in chunks to prevent UI blocking
        final excelService = ExcelService(_db!);

        // Update status during processing
        setState(() => _status = 'جاري قراءة الملف وتحليل البيانات...');
        await Future.delayed(const Duration(milliseconds: 100));

        // Use the new validation method
        final result = await _processFileWithValidation(excelService, file);

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
        debugPrint('Error processing file: $e');
        setState(() => _status = 'خطأ في معالجة الملف: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _processFileWithValidation(
    ExcelService excelService,
    File file,
  ) async {
    // First validate badge uniqueness
    setState(() => _status = 'جاري التحقق من صحة البيانات...');
    await Future.delayed(const Duration(milliseconds: 200));

    // Use the new validation method from ExcelService
    final validationResult = await excelService.processExcelFileWithValidation(
      file,
    );

    return validationResult;
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
      debugPrint('Error processing config sheet: $e');
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
      _staffAssignmentsExists = tables.contains(
        'Staff_Assignments',
      ); // Check for Staff Assignments table
    });
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}
