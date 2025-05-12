import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'database_service.dart';

class ViewDataScreen extends StatefulWidget {
  final Database? db;

  const ViewDataScreen({Key? key, required this.db}) : super(key: key);

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen> {
  // Add this field to track all processed badge numbers
  final Set<String> _processedBadgeNumbers = {};

  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late DataGridSource _dataSource;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _isLoadingMore = false;
  final DataGridController _dataGridController = DataGridController();

  // Pagination state
  int _totalRecords = 0;

  // Keep this as it's used for data fetching
  final int _pageSize = 30;

  // Map English column names to Arabic
  final Map<String, String> _arabicColumnNames = {};

  @override
  void initState() {
    super.initState();
    _loadTables();
    _verticalScrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_verticalScrollController.position.pixels >=
            _verticalScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore) {
      _loadTableData(_selectedTable!, loadMore: true);
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
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
      final tables = await DatabaseService.getAvailableTables(widget.db!);
      setState(() {
        _tables = tables;
        _isLoading = false;
        if (tables.isNotEmpty) {
          _selectedTable = tables.last; // Always pick the latest table
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
        _processedBadgeNumbers.clear(); // Clear the set when starting fresh
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

      // Process data with cross-batch duplicate checking
      final processedData = _processAndMarkDifferentCells(
        data,
        checkExisting: loadMore,
      );

      setState(() {
        if (!loadMore) {
          _tableData = processedData;
        } else {
          _tableData.addAll(processedData);
        }
        _isLoading = false;
        _isLoadingMore = false;
        
        // Filter out the ID column before passing to the data source
        final visibleColumns = _columns.where((column) => column != 'id' && !column.endsWith('_highlighted')).toList();
        
        _dataSource = _TableDataSource(
          _tableData,
          visibleColumns,
          _arabicColumnNames,
        );
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
  }

  // Process and mark cells that differ between consecutive records with the same Badge NO
  List<Map<String, dynamic>> _processAndMarkDifferentCells(
    List<Map<String, dynamic>> data, {
    bool checkExisting = false,
  }) {
    if (data.isEmpty) return [];

    final badgeNoColumn = _columns.firstWhere(
      (col) =>
          col.toLowerCase().contains('badge') ||
          col.toLowerCase().contains('رقم') ||
          col.toLowerCase().contains('الرقم'),
      orElse: () => '',
    );

    if (badgeNoColumn.isEmpty) {
      return data; // No Badge NO column found, return original data
    }

    // First, remove exact duplicates from the incoming data
    final uniqueData = <Map<String, dynamic>>[];
    for (final record in data) {
      bool isDuplicate = false;

      for (final uniqueRecord in uniqueData) {
        bool allFieldsMatch = true;
        
        // Compare all fields except metadata fields and id
        for (final column in _columns) {
          if (column.endsWith('_highlighted') || column == 'id') continue;
          
          if (record[column]?.toString() != uniqueRecord[column]?.toString()) {
            allFieldsMatch = false;
            break;
          }
        }
        
        if (allFieldsMatch) {
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        uniqueData.add(record);
      }
    }
    
    // Now group by badge number for highlighting differences
    final Map<String, List<Map<String, dynamic>>> recordsByBadgeNo = {};

    // Group records by Badge NO
    for (final record in uniqueData) {
      final badgeNo = record[badgeNoColumn]?.toString() ?? '';
      if (badgeNo.isEmpty) continue;

      recordsByBadgeNo
          .putIfAbsent(badgeNo, () => [])
          .add(Map<String, dynamic>.from(record));
    }

    // Process and mark different cells for each group
    final processedData = <Map<String, dynamic>>[];

    for (final entry in recordsByBadgeNo.entries) {
      final badgeNo = entry.key;
      final records = entry.value;

      // Skip if we've already processed this badge number in a previous batch
      if (checkExisting && _processedBadgeNumbers.contains(badgeNo)) {
        continue;
      }

      // Add to processed set to prevent future duplicates
      if (checkExisting) {
        _processedBadgeNumbers.add(badgeNo);
      }

      // If only one record with this Badge NO, add it as is
      if (records.length == 1) {
        processedData.add(records.first);
        continue;
      }

      // Add first record as is
      processedData.add(records.first);

      // Compare each record with the previous one
      for (int i = 1; i < records.length; i++) {
        final previousRecord = records[i - 1];
        final currentRecord = records[i];

        // Compare
        for (final column in _columns) {
          // Skip Badge NO column in comparison
          if (column == badgeNoColumn) continue;

          if (previousRecord[column]?.toString() !=
              currentRecord[column]?.toString()) {
            // Mark this cell as different by adding metadata
            currentRecord['${column}_highlighted'] = true;
          }
        }

        processedData.add(currentRecord);
      }
    }

    return processedData;
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'إسم الجدول: $_selectedTable',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp.clamp(16, 22),
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ),
          SizedBox(height: 8),

          // Table data using Syncfusion DataGrid with styling
          Expanded(
            child:
                _tableData.isEmpty
                    ? Center(
                      // ... existing empty state ...
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

  List<GridColumn> _buildGridColumns() {
    return _columns
        .where(
          (column) => !column.endsWith('_highlighted') && column != 'id',
        ) // Exclude metadata columns and id column
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
  }
}

class _TableDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Map<String, String> _arabicColumnNames;
  final VoidCallback? onNeedMoreData;

  _TableDataSource(
    this._data,
    this._columns,
    this._arabicColumnNames, {
    this.onNeedMoreData,
  }) {
    _dataGridRows =
        _data.map<DataGridRow>((dataRow) {
          return DataGridRow(
            cells:
                _columns.map<DataGridCell>((column) {
                  // Special handling for upload_date column
                  if (column == 'upload_date') {
                    final value = dataRow[column]?.toString() ?? '';
                    if (value.isNotEmpty) {
                      try {
                        final dateTime = DateTime.parse(value);
                        return DataGridCell<String>(
                          columnName: column,
                          value:
                              '${dateTime.toLocal().toString().split('.')[0]}',
                        );
                      } catch (e) {
                        return DataGridCell<String>(
                          columnName: column,
                          value: value,
                        );
                      }
                    }
                    return DataGridCell<String>(
                      columnName: column,
                      value: 'غير متوفر',
                    );
                  }
                  return DataGridCell<String>(
                    columnName: column,
                    value: dataRow[column]?.toString() ?? '',
                  );
                }).toList(),
          );
        }).toList();
  }

  List<DataGridRow> _dataGridRows = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      color: rows.indexOf(row) % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells:
          row.getCells().map<Widget>((dataGridCell) {
            // Check if this specific cell should be highlighted
            final isHighlighted =
                _data[rows.indexOf(row)].containsKey(
                  '${dataGridCell.columnName}_highlighted',
                ) &&
                _data[rows.indexOf(
                      row,
                    )]['${dataGridCell.columnName}_highlighted'] ==
                    true;

            // Skip rendering the metadata columns used for highlighting
            if (dataGridCell.columnName.endsWith('_highlighted')) {
              return Container();
            }

            if (dataGridCell.columnName == 'upload_date') {
              return Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  dataGridCell.value.toString(),
                  style: TextStyle(
                    color:
                        dataGridCell.value == 'غير متوفر'
                            ? Colors.red.shade300
                            : Colors.blue.shade800,
                    fontSize: 13,
                    fontWeight:
                        dataGridCell.value != 'غير متوفر'
                            ? FontWeight.w500
                            : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }

            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              decoration:
                  isHighlighted
                      ? BoxDecoration(
                        color: Colors.yellow.shade200,
                        border: Border.all(
                          color: Colors.orange.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      )
                      : null,
              child: Text(
                dataGridCell.value.toString(),
                style: TextStyle(
                  color:
                      isHighlighted
                          ? Colors.red.shade800
                          : Colors.grey.shade800,
                  fontSize: 13,
                  fontWeight:
                      isHighlighted ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
    );
  }

  @override
  int compare(DataGridRow? a, DataGridRow? b, SortColumnDetails sortColumn) {
    if (a == null || b == null) {
      return 0;
    }

    final String? valueA =
        a
            .getCells()
            .firstWhere((cell) => cell.columnName == sortColumn.name)
            .value;
    final String? valueB =
        b
            .getCells()
            .firstWhere((cell) => cell.columnName == sortColumn.name)
            .value;

    return sortColumn.sortDirection == DataGridSortDirection.ascending
        ? valueA?.compareTo(valueB ?? '') ?? 0
        : valueB?.compareTo(valueA ?? '') ?? 0;
  }
}
