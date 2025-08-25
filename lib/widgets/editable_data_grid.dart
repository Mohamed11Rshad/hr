import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/core/utils/validation_utils.dart';
import 'package:hr/widgets/common/base_data_grid.dart';
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:hr/utils/category_mapper.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart'; // Add this import

class EditableDataGrid extends BaseDataGrid {
  final Function(int, String, String) onCellUpdate;
  final Function(int) onDeleteRow;
  final String? selectedTable;
  final Function(int, String)? checkCellEditable;

  const EditableDataGrid({
    Key? key,
    required List<Map<String, dynamic>> data,
    required List<String> columns,
    required this.onCellUpdate,
    required this.onDeleteRow,
    this.selectedTable,
    this.checkCellEditable,
  }) : super(
         key: key,
         data: data,
         columns: columns,
         hiddenColumns: const <String>{},
       );

  @override
  _EditableDataGridState createState() => _EditableDataGridState();
}

class _EditableDataGridState extends BaseDataGridState<EditableDataGrid> {
  final Map<String, double> _columnWidths = {};
  int _filteredRecordCount = 0;
  _EditableDataSource? _dataSource; // Add this

  @override
  void initState() {
    super.initState();
    _initializeColumnWidths();
    _createDataSource(); // Add this
    // Initialize filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredRecordCount = widget.data.length;
      });
    });
  }

  void _createDataSource() {
    _dataSource = _EditableDataSource(
      widget.data,
      widget.columns,
      context: context,
      onCellUpdate: widget.onCellUpdate,
      onDeleteRow: widget.onDeleteRow,
      selectedTable: widget.selectedTable,
      checkCellEditable: widget.checkCellEditable,
    );
  }

  @override
  void didUpdateWidget(EditableDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate data source when data or columns change
    if (oldWidget.data != widget.data ||
        !_listsEqual(oldWidget.columns, widget.columns)) {
      _createDataSource();
      _initializeColumnWidths();
    }
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  void _initializeColumnWidths() {
    _columnWidths.clear();
    for (final column in widget.columns) {
      _columnWidths[column] = getColumnWidth(column);
    }
    initializeActionColumnWidths();
  }

  @override
  double getColumnWidth(String column) {
    switch (column.toLowerCase()) {
      case 'badge_no':
      case 'badge no':
        return 180.0;
      case 'employee_name':
      case 'employee name':
      case 'name':
        return 200.0;
      case "upload_date":
        return 230;
      case 'basic':
      case 'salary':
      case 'grade':
      case 'department':
      case 'dept':
      case 'depart_text':
        return 150.0;
      case 'position':
      case 'position_text':
      case 'upload_date':
      case 'adjusted_eligible_date':
      case 'last_promotion_dt':
      case 'bus_line':
        return 180.0;
      default:
        return 180.0;
    }
  }

  @override
  void initializeActionColumnWidths() {
    _columnWidths['actions'] = 100.0;
  }

  @override
  DataGridSource createDataSource() {
    return _dataSource!; // Return the stored data source
  }

  @override
  List<GridColumn> buildActionColumns() {
    return [
      GridColumn(
        columnName: 'actions',
        width: _columnWidths['actions'] ?? 100.0,
        minimumWidth: 20,
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
    ];
  }

  @override
  Color getHeaderColor() => AppColors.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Record count bar
        _buildRecordCountBar(),
        // Data grid
        Expanded(
          child: SfDataGridTheme(
            data: SfDataGridThemeData(
              headerColor: getHeaderColor(),
              gridLineColor: Colors.grey.shade300,
              gridLineStrokeWidth: 1.0,
              selectionColor: Colors.grey.shade400,
              filterIconColor: Colors.white,
              sortIconColor: Colors.white,
              columnDragIndicatorColor: Colors.black,
              columnDragIndicatorStrokeWidth: 4,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SfDataGrid(
                key: ValueKey(
                  widget.hiddenColumns.toString(),
                ), // Force rebuild when columns change
                source: _dataSource!, // Use the stored data source
                columnWidthMode: ColumnWidthMode.none,
                allowSorting: true,
                allowFiltering: true,
                allowColumnsDragging: false,
                selectionMode: SelectionMode.single,
                showHorizontalScrollbar: true,
                showVerticalScrollbar: true,
                isScrollbarAlwaysShown: true,
                gridLinesVisibility: GridLinesVisibility.both,
                headerGridLinesVisibility: GridLinesVisibility.both,
                rowHeight: 60,
                headerRowHeight: 65,
                allowColumnsResizing: true,
                columnResizeMode: ColumnResizeMode.onResize,
                onFilterChanged: (DataGridFilterChangeDetails details) {
                  // Update filtered count and force UI refresh
                  setState(() {
                    _filteredRecordCount = _dataSource!.effectiveRows.length;
                  });
                },
                onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                  setState(() {
                    _columnWidths[details.column.columnName] = details.width;
                  });
                  return true;
                },
                columns: _buildDataGridColumns(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCountBar() {
    final totalRecords = widget.data.length;
    final displayedRecords =
        _filteredRecordCount > 0 ? _filteredRecordCount : totalRecords;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: getHeaderColor().withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: getHeaderColor().withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: getHeaderColor()),
          const SizedBox(width: 8),
          if (_filteredRecordCount > 0 && _filteredRecordCount != totalRecords)
            Text(
              'عرض $displayedRecords من أصل $totalRecords سجل',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: getHeaderColor(),
              ),
            )
          else
            Text(
              'إجمالي السجلات: $totalRecords',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: getHeaderColor(),
              ),
            ),
          const Spacer(),
          if (_filteredRecordCount > 0 && _filteredRecordCount != totalRecords)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                'مفلتر',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<GridColumn> _buildDataGridColumns() {
    final columns =
        widget.columns.map((column) {
          return GridColumn(
            columnName: column,
            width: _columnWidths[column] ?? getColumnWidth(column),
            minimumWidth: 20,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList();

    columns.addAll(buildActionColumns());
    return columns;
  }
}

class _EditableDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final BuildContext context;
  final Function(int, String, String) onCellUpdate;
  final Function(int) onDeleteRow;
  final String? selectedTable;
  final Function(int, String)? checkCellEditable;
  List<DataGridRow> _dataGridRows = [];

  _EditableDataSource(
    this._data,
    this._columns, {
    required this.context,
    required this.onCellUpdate,
    required this.onDeleteRow,
    this.selectedTable,
    this.checkCellEditable,
  }) {
    _buildDataGridRows();
  }

  void updateData(List<Map<String, dynamic>> newData, List<String> newColumns) {
    _data.clear();
    _data.addAll(newData);
    _columns.clear();
    _columns.addAll(newColumns);
    _buildDataGridRows();
    notifyListeners();
  }

  void _buildDataGridRows() {
    _dataGridRows =
        _data.map<DataGridRow>((dataRow) {
          return DataGridRow(
            cells:
                _columns.map<DataGridCell>((column) {
                  String value = dataRow[column]?.toString() ?? '';

                  // Format upload_date column to match Base_Sheet format
                  if (column == 'upload_date' && value.isNotEmpty) {
                    value = _formatUploadDate(value);
                  }

                  return DataGridCell<String>(columnName: column, value: value);
                }).toList(),
          );
        }).toList();
  }

  String _formatUploadDate(String dateValue) {
    if (dateValue.isEmpty) return dateValue;

    try {
      // Parse the date if it's in ISO format
      DateTime dateTime;
      if (dateValue.contains('T')) {
        dateTime = DateTime.parse(dateValue);
      } else {
        // Try to parse other formats
        dateTime = DateTime.tryParse(dateValue) ?? DateTime.now();
      }

      // Format to match Base_Sheet format: 2025-6-17 11:33pm
      final year = dateTime.year;
      final month = dateTime.month;
      final day = dateTime.day;
      final hour =
          dateTime.hour > 12
              ? dateTime.hour - 12
              : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'pm' : 'am';

      return '$year-$month-$day $hour:$minute$period';
    } catch (e) {
      print('Error formatting upload date: $e');
      return dateValue; // Return original value if parsing fails
    }
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    // Only build cells for visible columns (matching the _columns list)
    final cells =
        _columns.map<Widget>((column) {
          // Find the corresponding cell in the row
          final dataGridCell = row.getCells().firstWhere(
            (cell) => cell.columnName == column,
            orElse: () => DataGridCell(columnName: column, value: ''),
          );

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4.0),
            child: FutureBuilder<bool>(
              future: _isCellEditableAsync(rowIndex, dataGridCell.columnName),
              builder: (context, snapshot) {
                final isEditable = snapshot.data ?? true;

                return InkWell(
                  onTap:
                      isEditable
                          ? () => _showEditDialog(
                            rowIndex,
                            dataGridCell.columnName,
                            dataGridCell.value.toString(),
                          )
                          : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isEditable
                                ? AppColors.primaryColor.withAlpha(150)
                                : Colors.grey.shade600,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color:
                          isEditable
                              ? AppColors.primaryColor.withAlpha(50)
                              : Colors.grey.shade300,
                    ),
                    child: Text(
                      dataGridCell.value.toString().isEmpty
                          ? (isEditable ? 'Click to edit' : 'Not editable')
                          : dataGridCell.value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isEditable
                                ? (dataGridCell.value.toString().isEmpty
                                    ? Colors.grey.shade600
                                    : AppColors.primaryColor)
                                : Colors.grey.shade600,
                        fontStyle:
                            dataGridCell.value.toString().isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList();

    // Add delete button
    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4.0),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => onDeleteRow(rowIndex),
          tooltip: 'حذف السجل',
        ),
      ),
    );

    return DataGridRowAdapter(color: Colors.white, cells: cells);
  }

  Future<bool> _isCellEditableAsync(int rowIndex, String columnName) async {
    // For Base_Sheet table, check specific restrictions
    if (selectedTable == 'Base_Sheet') {
      // Badge_NO and Employee_Name are never editable
      if (columnName == 'Badge_NO' || columnName == 'Employee_Name') {
        return false;
      }

      // Basic column is now always editable - removed promotion process check
    }

    // All other cells are editable
    return true;
  }

  bool _isCellEditable(int rowIndex, String columnName) {
    // For Base_Sheet table, only Badge_NO and Employee_Name are non-editable
    if (selectedTable == 'Base_Sheet') {
      if (columnName == 'Badge_NO' || columnName == 'Employee_Name') {
        return false;
      }
    }

    // All other cells are editable
    return true;
  }

  void _showEditDialog(
    int rowIndex,
    String columnName,
    String currentValue,
  ) async {
    // Check if this cell is editable
    if (!_isCellEditable(rowIndex, columnName)) {
      CustomSnackbar.showError(context, 'هذا الحقل غير قابل للتعديل');
      return;
    }

    final controller = TextEditingController(text: currentValue);
    String? errorMessage;
    String? selectedCategory = currentValue.isNotEmpty ? currentValue : null;

    // Check if this is a category field
    final isCategoryField = columnName.toLowerCase() == 'pay_scale_area_text';
    // Check if this is a date field
    final isDateField = _isDateField(columnName);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('تعديل $columnName'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show warning for Base_Sheet edits
                      if (selectedTable == 'Base_Sheet') ...[
                        const SizedBox(height: 12),
                      ],
                      // Show category dropdown for pay_scale_area_text field
                      if (isCategoryField)
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'فئة السلم الوظيفي',
                            border: const OutlineInputBorder(),
                            errorText: errorMessage,
                          ),
                          items:
                              CategoryMapper.getAllCategories().map((category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value;
                              controller.text = value ?? '';
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى اختيار فئة السلم الوظيفي';
                            }
                            return null;
                          },
                        )
                      else
                        TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: columnName,
                            border: const OutlineInputBorder(),
                            hintText:
                                isDateField
                                    ? 'أدخل التاريخ بصيغة: يوم.شهر.سنة (مثال: 15.03.2024)'
                                    : 'أدخل القيمة...',
                            errorText: errorMessage,
                          ),
                          maxLines: isDateField ? 1 : 3,
                          maxLength: isDateField ? 50 : 500,
                          onChanged: (value) {
                            if (isDateField) {
                              setDialogState(() {
                                if (value.isNotEmpty &&
                                    !ValidationUtils.isValidDate(value)) {
                                  errorMessage =
                                      ValidationUtils.getDateValidationError(
                                        value,
                                      );
                                } else {
                                  errorMessage = null;
                                }
                              });
                            }
                          },
                        ),
                      if (isDateField) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'الصيغة المقبولة: يوم.شهر.سنة (مثال: 15.03.2024) أو يوم/شهر/سنة',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed:
                          errorMessage == null
                              ? () {
                                final value =
                                    isCategoryField
                                        ? selectedCategory ?? ''
                                        : controller.text.trim();

                                if (isDateField &&
                                    value.isNotEmpty &&
                                    !ValidationUtils.isValidDate(value)) {
                                  setDialogState(() {
                                    errorMessage =
                                        ValidationUtils.getDateValidationError(
                                          value,
                                        );
                                  });
                                } else if (isCategoryField && value.isEmpty) {
                                  setDialogState(() {
                                    errorMessage =
                                        'يرجى اختيار فئة السلم الوظيفي';
                                  });
                                } else {
                                  Navigator.of(context).pop(value);
                                }
                              }
                              : null,
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
          ),
    );

    if (result != null) {
      onCellUpdate(rowIndex, columnName, result);
      // Update the local data and refresh the grid
      _data[rowIndex][columnName] = result;
      _buildDataGridRows();
      notifyListeners();
    }
  }

  // Add helper method to identify date fields
  bool _isDateField(String columnName) {
    final dateFields = {
      'date_of_join',
      'last_promotion_dt',
      'due_date',
      'recommended_date',
      'eligible_date',
      'adjusted_eligible_date',
      'retirement_date',
      'upload_date',
      'created_date',
      'promoted_date',
    };

    return dateFields.contains(columnName.toLowerCase()) ||
        columnName.toLowerCase().contains('date') ||
        columnName.toLowerCase().contains('dt');
  }
}
