import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for clipboard functionality
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class ViewLatestDataScreen extends StatefulWidget {
  final Database? db;
  final String? tableName;

  const ViewLatestDataScreen({
    Key? key,
    required this.db,
    required this.tableName,
  }) : super(key: key);

  @override
  State<ViewLatestDataScreen> createState() => _ViewLatestDataScreenState();
}

class _ViewLatestDataScreenState extends State<ViewLatestDataScreen> {
  List<Map<String, dynamic>> _latestData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late DataGridSource _dataSource;
  final Set<String> _hiddenColumns = <String>{};

  // Empty column names mapping since we're using original column names
  final Map<String, String> _columnNames = {};

  @override
  void initState() {
    super.initState();
    _loadLatestData();
  }

  Future<void> _loadLatestData() async {
    if (widget.db == null || widget.tableName == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Database or table not available';
      });
      print(
        "Database or table name is null: db=${widget.db}, tableName=${widget.tableName}",
      );
      return;
    }

    try {
      print("Loading data from table: ${widget.tableName}");

      // First, check if the table exists and has data
      final tableCheck = await widget.db!.rawQuery(
        "SELECT count(*) as count FROM \"${widget.tableName}\"",
      );
      final recordCount = tableCheck.first['count'] as int? ?? 0;
      print("Table ${widget.tableName} has $recordCount records");

      if (recordCount == 0) {
        setState(() {
          _isLoading = false;
          _latestData = [];
        });
        return;
      }

      // Find the Badge NO column name in the sanitized format
      final tableInfo = await widget.db!.rawQuery(
        'PRAGMA table_info("${widget.tableName}")',
      );
      print("Table columns: ${tableInfo.map((c) => c['name']).toList()}");

      // Try multiple patterns to find the badge column
      final badgeNoColumn = tableInfo
          .map((col) => col['name'].toString())
          .firstWhere(
            (name) => name.toLowerCase().contains('badge'),
            orElse: () => 'id', // Fallback to id if no badge column found
          );

      print("Using badge column: $badgeNoColumn");

      // Try a simpler query first to see if we can get any data
      final simpleData = await widget.db!.query(widget.tableName!, limit: 10);
      print("Simple query returned ${simpleData.length} records");

      if (simpleData.isEmpty) {
        setState(() {
          _isLoading = false;
          _latestData = [];
          _errorMessage = 'Cannot read data from table';
        });
        return;
      }

      // Now try the more complex query
      final sql = '''
        SELECT t.*
        FROM "${widget.tableName}" t
        INNER JOIN (
          SELECT "$badgeNoColumn", MAX(id) AS max_id
          FROM "${widget.tableName}"
          GROUP BY "$badgeNoColumn"
        ) grouped
        ON t."$badgeNoColumn" = grouped."$badgeNoColumn" AND t.id = grouped.max_id
      ''';

      print("Executing SQL: $sql");

      final data = await widget.db!.rawQuery(sql);
      print("Query returned ${data.length} records");

      if (data.isNotEmpty) {
        _columns = data.first.keys.toList();
        print("Columns found: $_columns");
      } else {
        // If the complex query fails, use the simple data
        _columns = simpleData.first.keys.toList();
        print("Using simple data with columns: $_columns");

        setState(() {
          _latestData = simpleData;
          _isLoading = false;
          _dataSource = _LatestDataSource(simpleData, _columns);
        });
        return;
      }

      setState(() {
        _latestData = data;
        _isLoading = false;
        _dataSource = _LatestDataSource(data, _columns);
      });
    } catch (e) {
      print("Error loading data: $e");

      // Try a fallback approach - just load all data
      try {
        final allData = await widget.db!.query(widget.tableName!);
        if (allData.isNotEmpty) {
          print("Fallback query returned ${allData.length} records");
          _columns = allData.first.keys.toList();

          setState(() {
            _latestData = allData;
            _isLoading = false;
            _dataSource = _LatestDataSource(allData, _columns);
          });
          return;
        }
      } catch (fallbackError) {
        print("Fallback also failed: $fallbackError");
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: ${e.toString()}';
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (widget.tableName == null || _latestData.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    await ExcelExporter.exportToExcel(
      context: context,
      data: _latestData,
      columns: _columns,
      columnNames:
          _columnNames, // Using empty mapping to keep original column names
      tableName: "${widget.tableName!}_latest",
    );

    setState(() {
      _isLoading = false;
    });
  }

  // Method to copy cell content to clipboard
  void _copyCellContent(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم النسخ'), duration: const Duration(seconds: 2)),
    );
  }

  void _refreshDataSource() {
    final visibleColumns =
        _columns.where((column) => !_hiddenColumns.contains(column)).toList();

    _dataSource = _LatestDataSource(_latestData, visibleColumns);
    setState(() {}); // Trigger rebuild
  }

  void _showColumnVisibilityDialog() {
    // Include all columns including 'id' in the dialog
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage));
    }

    if (_latestData.isEmpty) {
      return const Center(child: Text('No data available.'));
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
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.tableName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp.clamp(16, 22),
                        color: AppColors.primaryColor,
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
                  child: SfDataGrid(
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
                      if (rowIndex >= 0 && rowIndex < _latestData.length) {
                        final cellValue =
                            _latestData[rowIndex][details.column.columnName]
                                ?.toString() ??
                            '';
                        _copyCellContent(cellValue);
                      }
                    },
                    columns:
                        _columns
                            .where((column) => !_hiddenColumns.contains(column))
                            .map(
                              (column) => GridColumn(
                                columnName: column,
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Text(
                                    column,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  List<DataGridRow> _dataGridRows = [];

  _LatestDataSource(this._data, this._columns) {
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
