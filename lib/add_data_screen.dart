import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/database_service.dart';
import 'package:hr/excel_services.dart';
import 'package:hr/file_picker_service.dart';
import 'package:hr/promotions_screen.dart'; // Add this import
import 'package:hr/view_data_screen.dart';
import 'package:hr/view_latest_data_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AddDataScreen extends StatefulWidget {
  const AddDataScreen({super.key});

  @override
  State<AddDataScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<AddDataScreen> {
  String _status = 'جاهز لرفع ملف Excel';
  bool _isLoading = false;
  // Add these state variables after the existing ones in the _MainScreenState class
  bool _salaryScaleAExists = false;
  bool _salaryScaleBExists = false;
  bool _annualIncreaseAExists = false;
  bool _annualIncreaseBExists = false;
  final FilePickerService _filePicker = FilePickerService();
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
    await _updateLatestTable();
    await _checkConfigTables(); // Add this line
  }

  Future<void> _updateLatestTable() async {
    if (_db != null) {
      final tables = await DatabaseService.getAvailableTables(_db!);
      if (tables.isNotEmpty) {
        _latestTable = tables.last; // Pick the last table as the latest
      } else {
        _latestTable = null;
      }
      setState(() {});
    }
  }

  Future<void> _processExcelFile() async {
    File? file;
    if (_db == null) return;

    setState(() {
      _isLoading = true;
      _status = 'جاري تحميل ملف Excel...';
    });

    try {
      file = await _filePicker.pickExcelFile();
      if (file != null) {
        setState(() => _status = 'جاري معالجة الملف...');
        final excelService = ExcelService(_db!);
        _status = await excelService.processExcelFile(file);

        // After processing, update the latest table
        await _updateLatestTable();
      } else {
        _status = 'لم يتم اختيار ملف';
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('duplicate column name')) {
        // Extract all duplicated column names from the Excel file
        final duplicatedColumns = _findDuplicatedColumns(file);
        if (duplicatedColumns.isNotEmpty) {
          _status = 'خطأ: الأعمدة  ${duplicatedColumns.join(', ')} مكررة';
        } else {
          _status = 'خطأ: يوجد أعمدة مكررة في الملف';
        }
      } else {
        _status = 'خطأ في معالجة الملف}';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,

        title: Text(
          _selectedIndex == 0
              ? 'إضافة بيانات'
              : _selectedIndex == 1
              ? 'سجل المتغيرات'
              : _selectedIndex == 2
              ? 'عرض أحدث البيانات'
              : 'الترقيات',
          style: TextStyle(
            fontSize: 18.sp.clamp(16, 22),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(height: 48),
            ListTile(
              title: Text('إضافة بيانات'),
              selected: _selectedIndex == 0,
              selectedColor: AppColors.primaryColor,
              titleTextStyle: TextStyle(fontSize: 16.sp.clamp(16, 22)),
              textColor: Colors.black,
              selectedTileColor: AppColors.primaryColor.withAlpha(40),

              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 12),

            ListTile(
              title: Text('عرض البيانات'),
              selected: _selectedIndex == 1,
              selectedColor: AppColors.primaryColor,
              titleTextStyle: TextStyle(fontSize: 16.sp.clamp(16, 22)),
              textColor: Colors.black,
              selectedTileColor: AppColors.primaryColor.withAlpha(40),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 12),

            ListTile(
              title: const Text('عرض أحدث البيانات'),
              selected: _selectedIndex == 2,
              selectedColor: AppColors.primaryColor,
              titleTextStyle: TextStyle(fontSize: 16.sp.clamp(16, 22)),
              textColor: Colors.black,
              selectedTileColor: AppColors.primaryColor.withAlpha(40),
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 12),

            // Add new menu item for Promotions
            ListTile(
              title: const Text('الترقيات'),
              selected: _selectedIndex == 3,
              selectedColor: AppColors.primaryColor,
              titleTextStyle: TextStyle(fontSize: 16.sp.clamp(16, 22)),
              textColor:
                  _salaryScaleAExists &&
                          _salaryScaleBExists &&
                          _annualIncreaseAExists &&
                          _annualIncreaseBExists
                      ? Colors.black
                      : Colors.grey,
              selectedTileColor: AppColors.primaryColor.withAlpha(40),
              onTap: () {
                // Only navigate if all config tables exist
                if (_salaryScaleAExists &&
                    _salaryScaleBExists &&
                    _annualIncreaseAExists &&
                    _annualIncreaseBExists) {
                  _onItemTapped(3);
                  Navigator.pop(context);
                } else {
                  // Show a message explaining why they can't access this screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'يجب رفع جميع شيتات حساب الزيادة أولاً قبل الوصول إلى شاشة الترقيات',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
      body:
          _selectedIndex == 0
              ? _buildAddDataScreen()
              : _selectedIndex == 1
              ? ViewDataScreen(db: _db)
              : _selectedIndex == 2
              ? ViewLatestDataScreen(db: _db, tableName: "Base_Sheet")
              : PromotionsScreen(db: _db, tableName: "Base_Sheet"),
    );
  }

  Widget _buildAddDataScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 128),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                SizedBox(
                  height: 50.h.clamp(20, 60),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _processExcelFile,
                    child: const Text(
                      'رفع الملف الأساسي',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),

                // Configuration sheets section
                SizedBox(height: 30),
                Text(
                  'ملفات حساب الزيادة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),

                // Salary Scale A button
                Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor.withAlpha(
                              200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              _isLoading
                                  ? null
                                  : () => _processConfigSheet('Salary Scale A'),
                          child: SizedBox(
                            height: 50.h.clamp(20, 60),
                            width: 150.w.clamp(120, 180),
                            child: Center(
                              child: const Text(
                                'Salary Scale A',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_salaryScaleAExists)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 20.w.clamp(18, 22),
                              height: 20.w.clamp(18, 22),
                              decoration: BoxDecoration(
                                color: Colors.white54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: AppColors.primaryColor.withAlpha(250),
                                size: 16.w.clamp(14, 18),
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(width: 15),

                    // Salary Scale B button
                    Stack(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor.withAlpha(
                              200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              _isLoading
                                  ? null
                                  : () => _processConfigSheet('Salary Scale B'),
                          child: SizedBox(
                            height: 50.h.clamp(20, 60),
                            width: 150.w.clamp(120, 180),
                            child: Center(
                              child: const Text(
                                'Salary Scale B',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_salaryScaleBExists)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 20.w.clamp(18, 22),
                              height: 20.w.clamp(18, 22),
                              decoration: BoxDecoration(
                                color: Colors.white54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: AppColors.primaryColor.withAlpha(250),
                                size: 16.w.clamp(14, 18),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 15),

                // Annual Increase A button
                Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Annual Increase A button
                    Stack(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor.withAlpha(
                              200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              _isLoading
                                  ? null
                                  : () =>
                                      _processConfigSheet('Annual Increase A'),
                          child: SizedBox(
                            height: 50.h.clamp(20, 60),
                            width: 150.w.clamp(120, 180),
                            child: Center(
                              child: const Text(
                                'Annual Increase A',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_annualIncreaseAExists)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 20.w.clamp(18, 22),
                              height: 20.w.clamp(18, 22),
                              decoration: BoxDecoration(
                                color: Colors.white54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: AppColors.primaryColor.withAlpha(250),
                                size: 16.w.clamp(14, 18),
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(width: 15),

                    // Annual Increase B button
                    Stack(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor.withAlpha(
                              200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              _isLoading
                                  ? null
                                  : () =>
                                      _processConfigSheet('Annual Increase B'),
                          child: SizedBox(
                            height: 50.h.clamp(20, 60),
                            width: 150.w.clamp(120, 180),
                            child: Center(
                              child: const Text(
                                'Annual Increase B',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_annualIncreaseBExists)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 20.w.clamp(18, 22),
                              height: 20.w.clamp(18, 22),
                              decoration: BoxDecoration(
                                color: Colors.white54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: AppColors.primaryColor.withAlpha(250),
                                size: 16.w.clamp(14, 18),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 30),

                // Status text
                SizedBox(height: _isLoading ? 16 : 8),
                if (_isLoading)
                  LinearProgressIndicator(
                    color: AppColors.primaryColor,
                    backgroundColor: AppColors.primaryColor.withAlpha(40),
                  ),

                // Add this Text widget to display status message
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          _status.contains('خطأ') ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  Future<void> _processConfigSheet(String sheetName) async {
    File? file;
    if (_db == null) return;

    setState(() {
      _isLoading = true;
      _status = 'جاري تحميل ملف Excel...';
    });

    try {
      file = await _filePicker.pickExcelFile();
      if (file != null) {
        setState(() => _status = 'جاري معالجة الملف...');

        // Process the Excel file
        final bytes = file.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        // Check if the sheet with the specified name exists
        if (!excel.tables.containsKey(sheetName)) {
          setState(() {
            _status = 'خطأ: لا يوجد Sheet باسم "$sheetName" في الملف';
            _isLoading = false;
          });
          return;
        }

        final sheet = excel.tables[sheetName]!;
        final rows = sheet.rows;
        if (rows.isEmpty) {
          setState(() {
            _status = 'خطأ: Sheet "$sheetName" فارغة';
            _isLoading = false;
          });
          return;
        }

        // Get header row
        final headerRow = rows[0];
        final headers = <String>[];

        // Process headers
        for (var cell in headerRow) {
          final header = cell?.value.toString().trim() ?? '';
          if (header.isNotEmpty) {
            headers.add(header);
          }
        }

        if (headers.isEmpty) {
          setState(() {
            _status = 'خطأ: لا توجد عناوين في sheet "$sheetName"';
            _isLoading = false;
          });
          return;
        }

        // Check for duplicate headers
        final uniqueHeaders = headers.toSet();
        if (uniqueHeaders.length != headers.length) {
          setState(() {
            _status = 'خطأ: يوجد عناوين مكررة في sheet "$sheetName"';
            _isLoading = false;
          });
          return;
        }

        // Create a valid table name by replacing spaces with underscores
        final tableName = sheetName.replaceAll(' ', '_');

        // Check if table exists
        final tables = await _db!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
          [tableName],
        );

        // If table exists, drop it
        if (tables.isNotEmpty) {
          await _db!.execute('DROP TABLE "$tableName"');
        }

        // Create table
        final columns = headers
            .map((h) => '${_escapeColumnName(h)} TEXT')
            .join(', ');
        await _db!.execute('''
          CREATE TABLE "$tableName" (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            $columns,
            upload_date TEXT
          )
        ''');

        // Insert data
        final batch = _db!.batch();
        final now = DateTime.now().toIso8601String();

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          final values = <String, dynamic>{};

          // Skip empty rows
          bool isEmpty = true;
          for (var cell in row) {
            if (cell?.value != null) {
              isEmpty = false;
              break;
            }
          }
          if (isEmpty) continue;

          // Process row data
          for (int j = 0; j < headers.length && j < row.length; j++) {
            final cell = row[j];
            final value = cell?.value?.toString() ?? '';
            values[headers[j]] = value;
          }

          values['upload_date'] = now;
          batch.insert(tableName, values);
        }

        // Execute batch
        await batch.commit();
        await _checkConfigTables();

        setState(() {
          _status = 'تم إضافة بيانات "$sheetName" بنجاح';
        });
      } else {
        _status = 'لم يتم اختيار ملف';
      }
    } catch (e) {
      _status = 'خطأ في معالجة الملف';
      debugPrint('Error processing config sheet: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _escapeColumnName(String name) {
    // Sanitize column name for SQLite
    final sanitized = name.replaceAll('"', '""');
    return '"$sanitized"';
  }

  Future<void> _checkConfigTables() async {
    if (_db == null) return;

    final tables = await DatabaseService.getAvailableTables(_db!);

    setState(() {
      // Check for tables with underscores (since we replace spaces with underscores)
      _salaryScaleAExists = tables.contains('Salary_Scale_A');
      _salaryScaleBExists = tables.contains('Salary_Scale_B');
      _annualIncreaseAExists = tables.contains('Annual_Increase_A');
      _annualIncreaseBExists = tables.contains('Annual_Increase_B');
    });
  }
}
