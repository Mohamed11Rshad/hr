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
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late DataGridSource _dataSource;
  final ScrollController _horizontalScrollController = ScrollController();

  // Map English column names to Arabic
  final Map<String, String> _arabicColumnNames = {};

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
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

  Future<void> _loadTableData(String tableName) async {
    setState(() {
      _isLoading = true;
      _tableData = [];
      _columns = [];
    });

    try {
      // Get table data
      final data = await widget.db!.query(tableName);

      // Extract column names from the first row
      if (data.isNotEmpty) {
        _columns = data.first.keys.toList();
      }

      setState(() {
        _tableData = data;
        _isLoading = false;
        _dataSource = _TableDataSource(data, _columns, _arabicColumnNames);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });
    }
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
          // Show the table name as a header instead of a dropdown
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
          const SizedBox(height: 16),

          // Table data using Syncfusion DataGrid with styling
          Expanded(
            child:
                _tableData.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.table_rows_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'لا توجد بيانات في هذا الجدول',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : Directionality(
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
                          headerGridLinesVisibility: GridLinesVisibility.both,
                          rowHeight: 50,
                          headerRowHeight: 55,
                          frozenColumnsCount: 1,

                          allowColumnsResizing: true,

                          columns: _buildGridColumns(),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    return _columns.map((column) {
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
    }).toList();
  }
}

class _TableDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Map<String, String> _arabicColumnNames;
  List<DataGridRow> _dataGridRows = [];

  _TableDataSource(this._data, this._columns, this._arabicColumnNames) {
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

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      color: rows.indexOf(row) % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells:
          row.getCells().map<Widget>((dataGridCell) {
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
              child: Text(
                dataGridCell.value.toString(),
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
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
