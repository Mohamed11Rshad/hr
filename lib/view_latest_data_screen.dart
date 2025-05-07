import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLatestData();
  }

  Future<void> _loadLatestData() async {
    if (widget.db == null || widget.tableName == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'قاعدة البيانات أو الجدول غير متوفر';
      });
      return;
    }

    try {
      final sql = '''
        SELECT t.*
        FROM "${widget.tableName}" t
        INNER JOIN (
          SELECT "Badge NO.", MAX(id) AS max_id
          FROM "${widget.tableName}"
          GROUP BY "Badge NO."
        ) grouped
        ON t."Badge NO." = grouped."Badge NO." AND t.id = grouped.max_id
      ''';

      final data = await widget.db!.rawQuery(sql);

      if (data.isNotEmpty) {
        _columns = data.first.keys.toList();
      }

      setState(() {
        _latestData = data;
        _isLoading = false;
        _dataSource = _LatestDataSource(data, _columns);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage, style: const TextStyle(fontFamily: 'Arial')),
      );
    }

    if (_latestData.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات متاحة.',
          style: TextStyle(fontFamily: 'Arial'),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfDataGridTheme(
          data: SfDataGridThemeData(
            headerColor: Colors.blue.shade700,
            gridLineColor: Colors.grey.shade300,
            gridLineStrokeWidth: 1.0,
            selectionColor: Colors.blue.shade100,
            filterIconColor: Colors.white,
            sortIconColor: Colors.white,
          ),
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
            columns:
                _columns
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
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
    );
  }
}
