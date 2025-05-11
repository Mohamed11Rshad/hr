import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/database_service.dart';
import 'package:hr/excel_services.dart';
import 'package:hr/file_picker_service.dart';
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
              : 'عرض أحدث البيانات',
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
          ],
        ),
      ),
      body:
          _selectedIndex == 0
              ? _buildAddDataScreen()
              : _selectedIndex == 1
              ? ViewDataScreen(db: _db)
              : ViewLatestDataScreen(db: _db, tableName: _latestTable),
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
                      'رفع ملف Excel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  child: Card(
                    color: Colors.grey[200],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'الحالة :',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: _isLoading ? 16 : 8),
                          if (_isLoading)
                            LinearProgressIndicator(
                              color: AppColors.primaryColor,
                              backgroundColor: AppColors.primaryColor.withAlpha(
                                40,
                              ),
                            ),
                        ],
                      ),
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
}
