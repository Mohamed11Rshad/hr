import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/services/database_service.dart';
import 'package:hr/utils/data_processor.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/widgets/table_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ViewDataScreen extends StatefulWidget {
  final Database? db;

  const ViewDataScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen> {
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  late TableDataSource _dataSource;
  final ScrollController _verticalScrollController = ScrollController();
  final int _pageSize = 80;
  final Set<String> _processedBadgeNumbers = {};
  String? _lastCopiedCellInfo;

  // Arabic column names mapping
  final Map<String, String> _arabicColumnNames = {
    'badge_no': 'رقم الشارة',
    'name': 'الاسم',
    'department': 'القسم',
    'position': 'المنصب',
    // Add more mappings as needed
  };

  // Add a set to track hidden columns
  final Set<String> _hiddenColumns = <String>{};
  final Set<String> _selectedCells = <String>{};

  @override
  void initState() {
    super.initState();
    _loadTables();
    _verticalScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_scrollListener);
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_verticalScrollController.position.pixels ==
        _verticalScrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || _selectedTable == null) return;
    await _loadTableData(_selectedTable!, loadMore: true);
  }

  Future<void> _loadTables() async {
    if (widget.db == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'قاعدة البيانات غير مهيأة';
      });
      return;
    }

    try {
      if (!widget.db!.isOpen) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'قاعدة البيانات مغلقة - يرجى إعادة تشغيل التطبيق';
        });
        return;
      }

      await widget.db!.rawQuery('SELECT 1');

      final allTables = await DatabaseService.getAvailableTables(widget.db!);

      // Filter out internal tables (tables used by the application internally)
      final internalTables = {'promoted_employees', 'promotions', 'transfers'};

      final tables =
          allTables.where((table) => !internalTables.contains(table)).toList();

      setState(() {
        _tables = tables;
        _isLoading = false;
        if (tables.isNotEmpty) {
          _selectedTable = 'Base_Sheet';
          _loadTableData(_selectedTable!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل الجداول: ${e.toString()}';
      });
    }
  }

  Future<void> _loadTableData(String tableName, {bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _tableData = [];
        _columns = [];
        _processedBadgeNumbers.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final offset = loadMore ? _tableData.length : 0;
      final data = await widget.db!.query(
        tableName,
        limit: _pageSize,
        offset: offset,
      );

      if (data.isEmpty) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      if (data.isNotEmpty && !loadMore) {
        _columns = data.first.keys.toList();
      }

      final processedData = DataProcessor.processAndMarkDifferentCells(
        data,
        _columns,
        _processedBadgeNumbers,
        existingData: _tableData,
        checkExisting: loadMore,
      );

      setState(() {
        if (!loadMore) {
          _tableData = processedData;
        } else {
          for (final record in processedData) {
            if (!_tableData.any((existing) => existing['id'] == record['id'])) {
              _tableData.add(record);
            }
          }
        }
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

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    if (widget.db == null || _selectedTable == null) return;

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
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

      if (confirmed != true) return;

      // Delete from database
      await widget.db!.delete(
        _selectedTable!,
        where: 'id = ?',
        whereArgs: [record['id']],
      );

      // Update UI by removing the record and refreshing data source
      setState(() {
        _tableData.removeWhere((item) => item['id'] == record['id']);
        // Refresh the data source with proper column synchronization
        _refreshDataSource();
      });

      // Show success message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العنصر بنجاح')));
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف العنصر: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportToExcel() async {
    if (_selectedTable == null) return;

    setState(() {
      _isLoading = true;
    });

    await ExcelExporter.exportToExcel(
      context: context,
      data: _tableData,
      columns: _columns,
      columnNames: _arabicColumnNames,
      tableName: _selectedTable!,
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  // Add method to refresh data source with current column visibility
  void _refreshDataSource() {
    if (_tableData.isEmpty) {
      // Handle empty data case
      _dataSource = TableDataSource(
        [],
        [],
        _arabicColumnNames,
        onDeleteRecord: _deleteRecord,
        onCellSelected: _onCellSelected,
        onCopyCellContent: _copyCellContent,
      );
      return;
    }

    final visibleColumns =
        _columns
            .where(
              (column) =>
                  column != 'id' &&
                  !column.endsWith('_highlighted') &&
                  column !=
                      'Prom_Reason' && // Exclude Prom_Reason from base sheet view
                  !_hiddenColumns.contains(column),
            )
            .toList();

    _dataSource = TableDataSource(
      _tableData,
      visibleColumns,
      _arabicColumnNames,
      onDeleteRecord: _deleteRecord,
      onCellSelected: _onCellSelected,
      onCopyCellContent: _copyCellContent,
    );
  }

  void _onCellSelected(String cellValue) {
    setState(() {}); // Refresh to show selection changes
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_tables.isEmpty) {
      return const Center(
        child: Text('لا توجد جداول متاحة. يرجى رفع ملفات إكسل أولاً.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedTable != null)
            SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Positioned(
                    top: 2,
                    right: 0,
                    child: SizedBox(
                      height: 35,
                      child: Row(
                        children: [
                          // Column visibility button
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
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Table data using Syncfusion DataGrid with styling
          Expanded(
            child:
                _tableData.isEmpty
                    ? const Center(
                      child: Text('لا توجد بيانات متاحة لهذا الجدول.'),
                    )
                    : Stack(
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: SfDataGridTheme(
                            data: SfDataGridThemeData(
                              headerColor: Colors.blue.shade700,
                              gridLineColor: Colors.grey.shade300,
                              gridLineStrokeWidth: 1.0,
                              selectionColor: Colors.blue.shade100,
                              sortIconColor: Colors.white,
                              filterIconColor: Colors.white,
                              headerHoverColor: Colors.black.withAlpha(50),
                              filterIconHoverColor: Colors.black,
                              columnDragIndicatorColor: Colors.white,
                              columnDragIndicatorStrokeWidth: 2,
                            ),
                            child: SfDataGrid(
                              source: _dataSource,
                              columnWidthMode: ColumnWidthMode.auto,
                              allowSorting: true,
                              allowFiltering: true,
                              selectionMode: SelectionMode.single,
                              allowPullToRefresh: true,
                              showHorizontalScrollbar: true,
                              isScrollbarAlwaysShown: true,
                              showVerticalScrollbar: true,
                              gridLinesVisibility: GridLinesVisibility.both,
                              headerGridLinesVisibility:
                                  GridLinesVisibility.both,
                              rowHeight: 50,
                              headerRowHeight: 55,
                              frozenColumnsCount: 1,
                              allowColumnsResizing: true,
                              onCellSecondaryTap: (details) {
                                // Skip action column
                                if (details.column.columnName != 'actions') {
                                  final rowIndex =
                                      details.rowColumnIndex.rowIndex - 1;
                                  if (rowIndex >= 0 &&
                                      rowIndex < _tableData.length) {
                                    final cellValue =
                                        _tableData[rowIndex][details
                                                .column
                                                .columnName]
                                            ?.toString() ??
                                        '';

                                    // Add to clipboard collection instead of replacing
                                    final tableDataSource =
                                        _dataSource as TableDataSource;
                                    tableDataSource.addToClipboard(cellValue);
                                    final allValues =
                                        tableDataSource
                                            .getSelectedCellsAsText();
                                    Clipboard.setData(
                                      ClipboardData(text: allValues),
                                    );
                                    _copyCellContent(
                                      'تم إضافة إلى الحافظة (${tableDataSource.clipboardValuesCount} عنصر)',
                                    );
                                  }
                                }
                              },
                              onCellDoubleTap: (details) {
                                // Skip action column
                                if (details.column.columnName != 'actions') {
                                  final rowIndex =
                                      details.rowColumnIndex.rowIndex - 1;
                                  if (rowIndex >= 0 &&
                                      rowIndex < _tableData.length) {
                                    final cellValue =
                                        _tableData[rowIndex][details
                                                .column
                                                .columnName]
                                            ?.toString() ??
                                        '';

                                    // Clear clipboard and copy only this cell
                                    final tableDataSource =
                                        _dataSource as TableDataSource;
                                    tableDataSource.clearSelection();
                                    Clipboard.setData(
                                      ClipboardData(text: cellValue),
                                    );
                                    _copyCellContent('تم نسخ: $cellValue');
                                  }
                                }
                              },
                              verticalScrollController:
                                  _verticalScrollController,
                              columns: _buildGridColumns(),
                            ),
                          ),
                        ),
                        if (_isLoadingMore)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 16,
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
        ],
      ),
    );
  }

  // Add method to show column visibility dialog
  void _showColumnVisibilityDialog() {
    final visibleColumns =
        _columns
            .where(
              (column) =>
                  !column.endsWith('_highlighted') &&
                  column != 'id' &&
                  column !=
                      'Prom_Reason', // Exclude Prom_Reason from column visibility options
            )
            .toList();

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
                                  _arabicColumnNames[column] ?? column;

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

  // Update the _buildGridColumns method to respect hidden columns
  List<GridColumn> _buildGridColumns() {
    final columns =
        _columns
            .where(
              (column) =>
                  !column.endsWith('_highlighted') &&
                  column != 'id' &&
                  column !=
                      'Prom_Reason' && // Exclude Prom_Reason from grid columns
                  !_hiddenColumns.contains(column),
            )
            .map((column) {
              return GridColumn(
                columnName: column,
                label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: Text(
                    _arabicColumnNames[column] ?? column,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            })
            .toList();

    // Only add delete column if there are other visible columns
    if (columns.isNotEmpty) {
      columns.add(
        GridColumn(
          columnName: 'actions',
          width: 80,
          allowSorting: false,
          allowFiltering: false,
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: const Text(
              'حذف',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return columns;
  }

  // Update the _loadTableData method to call _refreshDataSource

  void _copyCellContent(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content), duration: const Duration(seconds: 2)),
    );
  }
}
