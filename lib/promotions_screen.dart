import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/database_service.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

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
  late _PromotionsDataSource _dataSource;
  final Set<String> _hiddenColumns = <String>{};

  // Add pagination variables
  final int _pageSize = 100;
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _verticalScrollController = ScrollController();

  // Column mapping for display names
  final Map<String, String> _columnNames = {
    'Badge_NO': 'Badge ID',
    'Employee_Name': 'Name',
    'Bus_Line': 'Business Line',
    'Depart_Text': 'Department',
    'Grade': 'Grade',
    'Status': 'Status',
    'Adjusted_Eligible_Date': 'Adjus Elig',
    'Basic': 'Old Basic',
    'Next_Grade': 'Next Grade',
    '4% Adj': '4% Adj',
    'Annual_Increment': 'Annual Increment',
    'New_Basic': 'New Basic',
    'Position_Text': 'Position',
    'Grade_Range': 'Grade Range',
    'Promotion_Band': 'Promotion Band',
    'Last_Promotion_Dt': 'Last Promotion',
  };

  // List of columns we want to display
  final List<String> _requiredColumns = [
    'Badge_NO',
    'Employee_Name',
    'Bus_Line',
    'Depart_Text',
    'Grade',
    'status',
    'Adjusted_Eligible_Date',
    'Basic',
    'Next_Grade',
    '4% Adj',
    'Annual_Increment',
    'New_Basic',
    'Position_Text',
    'Grade_Range',
    'Promotion_Band',
    'Last_Promotion_Dt',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();

    // Add scroll listener for pagination
    _verticalScrollController.addListener(_scrollListener);
  }

  // Add scroll listener method
  void _scrollListener() {
    if (_verticalScrollController.position.pixels >=
            _verticalScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _loadData() async {
    if (widget.db == null || widget.tableName == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'قاعدة البيانات غير متوفرة';
      });
      return;
    }

    try {
      // Get all columns from the table
      final tableInfo = await widget.db!.rawQuery(
        'PRAGMA table_info("${widget.tableName}")',
      );

      final allColumns =
          tableInfo.map((col) => col['name'].toString()).toList();

      // Filter columns to only include the ones we want
      _columns =
          _requiredColumns
              .where(
                (col) => allColumns.any(
                  (dbCol) =>
                      dbCol.toLowerCase() == col.toLowerCase() ||
                      dbCol.toLowerCase().contains(col.toLowerCase()),
                ),
              )
              .toList();

      // If we couldn't find all required columns, use what we have
      if (_columns.isEmpty) {
        _columns =
            allColumns
                .where((col) => col != 'id' && !col.endsWith('_highlighted'))
                .toList();
      }

      // Reset pagination variables
      _currentPage = 0;
      _hasMoreData = true;

      // Get first page of data
      await _loadMoreData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  // Add method to load more data
  Future<void> _loadMoreData() async {
    if (!_hasMoreData ||
        _isLoadingMore ||
        widget.db == null ||
        widget.tableName == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get data with pagination
      final offset = _currentPage * _pageSize;
      final data = await widget.db!.query(
        widget.tableName!,
        limit: _pageSize,
        offset: offset,
      );

      // Check if we have more data
      if (data.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Process the data to add calculated columns
      final processedData = await _processDataWithCalculatedColumns(data);

      setState(() {
        if (_currentPage == 0) {
          _promotionsData = processedData;
        } else {
          _promotionsData.addAll(processedData);
        }
        _currentPage++;
        _isLoading = false;
        _isLoadingMore = false;
        _refreshDataSource();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  // Add method to process data and add calculated columns
  Future<List<Map<String, dynamic>>> _processDataWithCalculatedColumns(
    List<Map<String, dynamic>> data,
  ) async {
    final processedData = <Map<String, dynamic>>[];

    // Add calculated columns to each record
    for (final record in data) {
      final newRecord = Map<String, dynamic>.from(record);

      // Calculate Next Grade (assuming 'Grade' column exists)
      final gradeValue = record['Grade']?.toString() ?? '';
      if (gradeValue.startsWith('0')) {
        gradeValue.replaceFirst('0', '');
      }
      String nextGrade = '';
      if (gradeValue.isNotEmpty) {
        try {
          // Parse the grade value, removing leading zeros
          final gradeInt =
              int.tryParse(gradeValue.replaceAll(RegExp(r'^0+'), '')) ?? 0;
          // Increment by 1
          nextGrade = (gradeInt + 1).toString();
          newRecord['Next_Grade'] = nextGrade;
        } catch (e) {
          // If parsing fails, just use the original value
          newRecord['Next_Grade'] = gradeValue;
        }
      } else {
        newRecord['Next_Grade'] = '';
      }

      // Calculate 4% Adj (assuming 'Basic' column exists)
      double oldBasic = 0;
      try {
        oldBasic = double.tryParse(record['Basic']?.toString() ?? '0') ?? 0;
      } catch (e) {
        // Handle parsing error
      }
      final fourPercentAdj = oldBasic * 0.04;
      newRecord['4% Adj'] = fourPercentAdj.toStringAsFixed(2);

      // Calculate Annual Increment
      double annualIncrement = 0;
      final adjustedEligibleDate =
          record['Adjusted_Eligible_Date']?.toString() ?? '';

      if (adjustedEligibleDate.isNotEmpty) {
        try {
          // Parse date which could be in format DD.MM.YYYY or DD/MM/YYYY
          DateTime date;
          if (adjustedEligibleDate.contains('.')) {
            final parts = adjustedEligibleDate.split('.');
            date = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } else if (adjustedEligibleDate.contains('/')) {
            final parts = adjustedEligibleDate.split('/');
            date = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } else {
            // Try standard format
            date = DateTime.parse(adjustedEligibleDate);
          }

          // Check if it's January 1st
          if (date.month == 1 && date.day == 1) {
            // Determine which tables to use based on pay_scale_area_text
            final payScaleArea =
                record['pay_scale_area_text']?.toString() ?? '';
            String salaryScaleTable = 'Salary_Scale_A';
            String annualIncreaseTable = 'Annual_Increase_A';

            if (payScaleArea.contains('Category B')) {
              salaryScaleTable = 'Salary_Scale_B';
              annualIncreaseTable = 'Annual_Increase_B';
            }
            print("++++++++++++++++++++++ ${gradeValue}");
            // Get data from Salary Scale table for the current grade
            // Assuming Salary Scale table has columns like 'Grade', 'Midpoint', 'Maximum'
            final salaryScaleData = await widget.db!.query(
              salaryScaleTable,
              where: 'Grade = ?',
              whereArgs: [nextGrade], // Use original grade value for lookup
            );

            double midpoint = 0;
            double maximum = 0;
            if (salaryScaleData.isNotEmpty) {
              debugPrint(
                '++++++++++++++++++++++++++ Salary Scale Data: $salaryScaleData',
              );
              midpoint =
                  double.tryParse(
                    salaryScaleData.first['midpoint']?.toString() ?? '0',
                  ) ??
                  0;
              maximum =
                  double.tryParse(
                    salaryScaleData.first['maximum']?.toString() ?? '0',
                  ) ??
                  0;
            }
            debugPrint(
              '-------------------------- Midpoint: $midpoint, Maximum: $maximum',
            );

            // Calculate (old base + 4% adj)
            final oldBasePlusAdj = oldBasic + fourPercentAdj;

            debugPrint(
              '-------------------------- Old Base: $oldBasic, 4% Adj: $fourPercentAdj, Old Base + Adj: $oldBasePlusAdj',
            );

            // Determine if below or above midpoint
            String midpointStatus = (oldBasePlusAdj < midpoint) ? 'b' : 'a';

            // Get data from Annual Increase table
            // Assuming Annual Increase table has columns like 'Appraisal', 'Below Midpoint', 'Above Midpoint'
            final appraisalValue =
                record['Appraisal5']?.toString().split('-')[1] ?? '';

            debugPrint(
              '-------------------------- Appraisal Value: $appraisalValue',
            );
            final annualIncreaseData = await widget.db!.query(
              annualIncreaseTable,
              where: 'Grade = ?',
              whereArgs: [nextGrade],
            );
            debugPrint(
              '-------------------------- Annual Increase Data: $annualIncreaseData',
            );
            double potentialAnnualIncrement = 0;
            if (annualIncreaseData.isNotEmpty) {
              if (midpointStatus == 'b') {
                potentialAnnualIncrement =
                    double.tryParse(
                      annualIncreaseData.first['${appraisalValue}_b']
                              ?.toString() ??
                          '0',
                    ) ??
                    0;
              } else {
                potentialAnnualIncrement =
                    double.tryParse(
                      annualIncreaseData.first['${appraisalValue}_a']
                              ?.toString() ??
                          '0',
                    ) ??
                    0;
              }
            }

            // Compare potential increment with maximum from Salary Scale
            annualIncrement = potentialAnnualIncrement;
            if (annualIncrement > maximum) {
              annualIncrement = maximum;
            }
            // Ensure increment is not negative
            if (annualIncrement < 0) {
              annualIncrement = 0;
            }
          }
        } catch (e) {
          // Handle date or calculation parsing error
          print('Error calculating annual increment: $e');
        }
      }
      newRecord['Annual_Increment'] = annualIncrement.toStringAsFixed(2);

      // Calculate New Basic
      final newBasic = oldBasic + fourPercentAdj + annualIncrement;
      newRecord['New_Basic'] = newBasic.toStringAsFixed(2);

      processedData.add(newRecord);
    }

    // Add the calculated columns to the columns list if not already present
    if (!_columns.contains('Next_Grade')) {
      _columns.add('Next_Grade');
    }
    if (!_columns.contains('4% Adj')) {
      _columns.add('4% Adj');
    }
    if (!_columns.contains('Annual_Increment')) {
      _columns.add('Annual_Increment');
    }
    if (!_columns.contains('New_Basic')) {
      _columns.add('New_Basic');
    }

    // Ensure Position_Text comes after New_Basic
    if (_columns.contains('Position_Text')) {
      // Remove it from its current position
      _columns.remove('Position_Text');
      // Add it after New_Basic
      final newBasicIndex = _columns.indexOf('New_Basic');
      if (newBasicIndex >= 0) {
        _columns.insert(newBasicIndex + 1, 'Position_Text');
      } else {
        _columns.add('Position_Text');
      }
    } else if (_columns.contains('New_Basic')) {
      // If Position_Text doesn't exist but New_Basic does, add it after New_Basic
      final newBasicIndex = _columns.indexOf('New_Basic');
      _columns.insert(newBasicIndex + 1, 'Position_Text');
    } else {
      // If neither exists, just add it
      _columns.add('Position_Text');
    }

    // Ensure Grade_Range comes after Position_Text
    if (_columns.contains('Grade_Range')) {
      // Remove it from its current position
      _columns.remove('Grade_Range');
      // Add it after Position_Text
      final positionTextIndex = _columns.indexOf('Position_Text');
      if (positionTextIndex >= 0) {
        _columns.insert(positionTextIndex + 1, 'Grade_Range');
      } else {
        _columns.add('Grade_Range');
      }
    } else if (_columns.contains('Position_Text')) {
      // If Grade_Range doesn't exist but Position_Text does, add it after Position_Text
      final positionTextIndex = _columns.indexOf('Position_Text');
      _columns.insert(positionTextIndex + 1, 'Grade_Range');
    } else {
      // If neither exists, just add it
      _columns.add('Grade_Range');
    }

    // Ensure Promotion_Band comes after Grade_Range
    if (_columns.contains('Promotion_Band')) {
      // Remove it from its current position
      _columns.remove('Promotion_Band');
      // Add it after Grade_Range
      final gradeRangeIndex = _columns.indexOf('Grade_Range');
      if (gradeRangeIndex >= 0) {
        _columns.insert(gradeRangeIndex + 1, 'Promotion_Band');
      } else {
        _columns.add('Promotion_Band');
      }
    } else if (_columns.contains('Grade_Range')) {
      // If Promotion_Band doesn't exist but Grade_Range does, add it after Grade_Range
      final gradeRangeIndex = _columns.indexOf('Grade_Range');
      _columns.insert(gradeRangeIndex + 1, 'Promotion_Band');
    } else {
      // If neither exists, just add it
      _columns.add('Promotion_Band');
    }

    // Ensure Last_Promotion_Dt comes after Promotion_Band
    if (_columns.contains('Last_Promotion_Dt')) {
      // Remove it from its current position
      _columns.remove('Last_Promotion_Dt');
      // Add it after Promotion_Band
      final promotionBandIndex = _columns.indexOf('Promotion_Band');
      if (promotionBandIndex >= 0) {
        _columns.insert(promotionBandIndex + 1, 'Last_Promotion_Dt');
      } else {
        _columns.add('Last_Promotion_Dt');
      }
    } else if (_columns.contains('Promotion_Band')) {
      // If Last_Promotion_Dt doesn't exist but Promotion_Band does, add it after Promotion_Band
      final promotionBandIndex = _columns.indexOf('Promotion_Band');
      _columns.insert(promotionBandIndex + 1, 'Last_Promotion_Dt');
    } else {
      // If neither exists, just add it
      _columns.add('Last_Promotion_Dt');
    }

    return processedData;
  }

  void _refreshDataSource() {
    final visibleColumns =
        _columns.where((column) => !_hiddenColumns.contains(column)).toList();

    _dataSource = _PromotionsDataSource(_promotionsData, visibleColumns);
  }

  void _showColumnVisibilityDialog() {
    final visibleColumns = _columns.toList();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('إظهار/إخفاء الأعمدة'),
                  content: SizedBox(
                    width: double.maxFinite.clamp(0, 800),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Add "Select All" checkbox
                        CheckboxListTile(
                          title: const Text('تحديد الكل'),
                          value: _hiddenColumns.isEmpty,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              setState(() {
                                if (value == true) {
                                  // Show all columns
                                  _hiddenColumns.clear();
                                } else {
                                  // Hide all columns
                                  _hiddenColumns.addAll(visibleColumns);
                                }
                              });
                            });

                            // Refresh the data source
                            _refreshDataSource();
                          },
                        ),
                        const Divider(),
                        // List of columns
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: visibleColumns.length,
                            itemBuilder: (context, index) {
                              final column = visibleColumns[index];
                              final displayName =
                                  _columnNames[column] ?? column;

                              return CheckboxListTile(
                                title: Text(displayName),
                                value: !_hiddenColumns.contains(column),
                                onChanged: (bool? value) {
                                  // Update both the dialog state and the widget state
                                  setDialogState(() {
                                    setState(() {
                                      if (value == false) {
                                        _hiddenColumns.add(column);
                                      } else {
                                        _hiddenColumns.remove(column);
                                      }
                                    });
                                  });

                                  // Refresh the data source with updated column visibility
                                  _refreshDataSource();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _copyCellContent(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم النسخ'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _isLoading = true;
    });

    await ExcelExporter.exportToExcel(
      context: context,
      data: _promotionsData,
      columns: _columns,
      columnNames: _columnNames,
      tableName: 'الترقيات',
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_promotionsData.isEmpty) {
      return const Center(child: Text('لا توجد بيانات متاحة.'));
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add export button and title
            SizedBox(
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
                            // Add column visibility button
                            ElevatedButton.icon(
                              onPressed: _showColumnVisibilityDialog,
                              icon: const Icon(
                                Icons.visibility,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'إظهار/إخفاء الأعمدة',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Export button
                            ElevatedButton.icon(
                              onPressed: _exportToExcel,
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
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.tableName ?? 'الترقيات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp.clamp(16, 22),
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Data grid
            Expanded(
              child: SfDataGridTheme(
                data: SfDataGridThemeData(
                  headerColor: Colors.blue.shade700,
                  gridLineColor: Colors.grey.shade300,
                  gridLineStrokeWidth: 1.0,
                  selectionColor: Colors.grey.shade400,
                  filterIconColor: Colors.white,
                  sortIconColor: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    children: [
                      SfDataGrid(
                        source: _dataSource,
                        columnWidthMode: ColumnWidthMode.auto,
                        allowSorting: true,
                        allowFiltering: true,
                        selectionMode: SelectionMode.single,
                        showHorizontalScrollbar: true,
                        showVerticalScrollbar: true,
                        isScrollbarAlwaysShown: true,
                        gridLinesVisibility: GridLinesVisibility.both,
                        headerGridLinesVisibility: GridLinesVisibility.both,
                        rowHeight: 50,
                        headerRowHeight: 55,
                        onCellSecondaryTap: (details) {
                          final rowIndex = details.rowColumnIndex.rowIndex - 1;
                          if (rowIndex >= 0 &&
                              rowIndex < _promotionsData.length) {
                            final cellValue =
                                _promotionsData[rowIndex][details
                                        .column
                                        .columnName]
                                    ?.toString() ??
                                '';
                            _copyCellContent(cellValue);
                          }
                        },
                        verticalScrollController: _verticalScrollController,
                        columns:
                            _columns
                                .where(
                                  (column) => !_hiddenColumns.contains(column),
                                )
                                .map(
                                  (column) => GridColumn(
                                    minimumWidth: 150,
                                    columnName: column,
                                    label: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _columnNames[column] ?? column,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),

                      // Add loading indicator at the bottom
                      if (_isLoadingMore)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            color: Colors.black.withOpacity(0.05),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('جاري تحميل المزيد...'),
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
          ],
        ),
      ),
    );
  }
}

class _PromotionsDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  List<DataGridRow> _dataGridRows = [];

  _PromotionsDataSource(this._data, this._columns) {
    _dataGridRows =
        _data
            .map<DataGridRow>(
              (dataRow) => DataGridRow(
                cells:
                    _columns
                        .map<DataGridCell>(
                          (column) => DataGridCell<String>(
                            columnName: column,
                            value: dataRow[column]?.toString() ?? '',
                          ),
                        )
                        .toList(),
              ),
            )
            .toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      color: rows.indexOf(row) % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells:
          row.getCells().map<Widget>((dataGridCell) {
            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                dataGridCell.value.toString(),
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
    );
  }
}
