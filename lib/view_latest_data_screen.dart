import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/excel_exporter.dart';
import 'package:hr/widgets/column_visibility_dialog.dart';
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
          _refreshDataSource();
        });
        return;
      }

      setState(() {
        _latestData = data;
        _isLoading = false;
        _refreshDataSource();
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
            _refreshDataSource();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content), duration: const Duration(seconds: 2)),
    );
  }

  void _refreshDataSource() {
    final visibleColumns =
        _columns
            .where(
              (column) =>
                  column !=
                      'Prom_Reason' && // Exclude Prom_Reason from latest data view
                  !_hiddenColumns.contains(column),
            )
            .toList();

    _dataSource = _LatestDataSource(
      _latestData,
      visibleColumns,
      onCellSelected: _onCellSelected,
      onCopyCellContent: _copyCellContent,
    );
    setState(() {}); // Trigger rebuild
  }

  void _onCellSelected(String cellValue) {
    setState(() {}); // Refresh to show selection changes
  }

  void _copySelectedCells() {
    final latestDataSource = _dataSource as _LatestDataSource;
    final selectedText = latestDataSource.getSelectedCellsAsText();

    if (selectedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: selectedText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ ${latestDataSource.selectedCellsCount} عنصر'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearSelection() {
    final latestDataSource = _dataSource as _LatestDataSource;
    latestDataSource.clearSelection();
    setState(() {});
  }

  void _showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ColumnVisibilityDialog(
            columns:
                _columns
                    .where((column) => column != 'Prom_Reason')
                    .toList(), // Exclude Prom_Reason
            columnNames: _columnNames,
            hiddenColumns: _hiddenColumns,
            onVisibilityChanged: _refreshDataSource,
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
            // Header without copy/clear buttons
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

                        // Add to clipboard collection instead of replacing
                        final latestDataSource =
                            _dataSource as _LatestDataSource;
                        latestDataSource.addToClipboard(cellValue);
                        final allValues =
                            latestDataSource.getSelectedCellsAsText();
                        Clipboard.setData(ClipboardData(text: allValues));
                        _copyCellContent(
                          'تم إضافة إلى الحافظة (${latestDataSource.clipboardValuesCount} عنصر)',
                        );
                      }
                    },
                    onCellDoubleTap: (details) {
                      final rowIndex = details.rowColumnIndex.rowIndex - 1;
                      if (rowIndex >= 0 && rowIndex < _latestData.length) {
                        final cellValue =
                            _latestData[rowIndex][details.column.columnName]
                                ?.toString() ??
                            '';

                        // Clear clipboard and copy only this cell
                        final latestDataSource =
                            _dataSource as _LatestDataSource;
                        latestDataSource.clearSelection();
                        Clipboard.setData(ClipboardData(text: cellValue));
                        _copyCellContent('تم نسخ: $cellValue');
                      }
                    },
                    columns: _buildGridColumns(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    return _columns
        .where(
          (column) =>
              column !=
                  'Prom_Reason' && // Exclude Prom_Reason from grid display
              !_hiddenColumns.contains(column),
        )
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
        .toList();
  }
}

class _LatestDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final Set<String> _clipboardValues = <String>{};
  final Function(String)? onCellSelected;
  final Function(String)? onCopyCellContent;
  List<DataGridRow> _dataGridRows = [];

  _LatestDataSource(
    this._data,
    this._columns, {
    this.onCellSelected,
    this.onCopyCellContent,
  }) {
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

  void clearSelection() {
    _clipboardValues.clear();
  }

  String getSelectedCellsAsText() {
    return _clipboardValues.join('\n');
  }

  int get selectedCellsCount => _clipboardValues.length;

  // Add public getter for clipboard values count
  int get clipboardValuesCount => _clipboardValues.length;

  // Add public method to add to clipboard
  void addToClipboard(String value) {
    _clipboardValues.add(value);
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = rows.indexOf(row);

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells:
          row.getCells().map<Widget>((dataGridCell) {
            return GestureDetector(
              onSecondaryTap: () {
                // Right click: add this cell value to clipboard collection
                final cellValue = dataGridCell.value.toString();
                _clipboardValues.add(cellValue);
                final allValues = _clipboardValues.join('\n');
                Clipboard.setData(ClipboardData(text: allValues));
                onCopyCellContent?.call(
                  'تم إضافة إلى الحافظة (${_clipboardValues.length} عنصر)',
                );
              },
              onDoubleTap: () {
                // Double click: clear clipboard and copy only this cell
                _clipboardValues.clear();
                final cellValue = dataGridCell.value.toString();
                Clipboard.setData(ClipboardData(text: cellValue));
                onCopyCellContent?.call('تم نسخ: $cellValue');
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  dataGridCell.value.toString(),
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
    );
  }
}
