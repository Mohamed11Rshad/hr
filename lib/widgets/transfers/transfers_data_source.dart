import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:hr/services/editable_data_service.dart';
import 'package:hr/services/database_service.dart';

class TransfersDataSource extends DataGridSource {
  final List<Map<String, dynamic>> _data;
  final List<String> _columns;
  final BuildContext context;
  final Function(Map<String, dynamic>)? onRemoveTransfer;
  final Function(Map<String, dynamic>)?
      onTransferEmployee; // New callback for direct transfer
  final Function(String, String, String)? onUpdateField;
  final Function(String)? onCopyCellContent;
  final Set<String> _clipboardValues = <String>{};
  List<DataGridRow> _dataGridRows = [];
  EditableDataService? _editableDataService;

  TransfersDataSource(
    this._data,
    this._columns, {
    required this.context,
    this.onRemoveTransfer,
    this.onTransferEmployee, // Add the new callback parameter
    this.onUpdateField,
    this.onCopyCellContent,
  }) {
    _buildDataGridRows();
    _initializeEditableDataService();
  }

  Future<void> _initializeEditableDataService() async {
    try {
      final db = await DatabaseService.openDatabase();
      _editableDataService = EditableDataService(db);
      await _editableDataService!.initializeEditableDataTable();
    } catch (e) {
      print('Error initializing editable data service: $e');
    }
  }

  void clearSelection() {
    _clipboardValues.clear();
  }

  String getSelectedCellsAsText() {
    return _clipboardValues.join('\n');
  }

  int get clipboardValuesCount => _clipboardValues.length;

  void addToClipboard(String value) {
    _clipboardValues.add(value);
  }

  void _buildDataGridRows() {
    _dataGridRows = _data.map<DataGridRow>((dataRow) {
      return DataGridRow(
        cells: _columns.map<DataGridCell>((column) {
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

  bool _isFieldEditable(String columnName) {
    const editableFields = {'ERD', 'POD', 'Available_in_ERD'};
    return editableFields.contains(columnName);
  }

  bool _isDropdownField(String columnName) {
    return columnName == 'DONE_YES_NO';
  }

  String _normalizeDropdownValue(String value) {
    // Normalize Arabic values to English for consistency
    switch (value.toLowerCase().trim()) {
      case 'تم':
      case 'done':
        return 'Done';
      case 'نعم':
      case 'yes':
        return 'Yes';
      case 'لا':
      case 'no':
        return 'No';
      case 'إلغاء':
      case 'cancel':
        return 'Cancel';
      default:
        return value.isEmpty ? '' : value;
    }
  }

  Widget _buildRegularCell(DataGridCell dataGridCell) {
    // Convert Arabic values to English for display
    final displayValue = dataGridCell.columnName == 'DONE_YES_NO'
        ? _normalizeDropdownValue(dataGridCell.value.toString())
        : dataGridCell.value.toString();

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        displayValue,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEditableCell(Map<String, dynamic> record, String columnName) {
    final badgeNo = record['Badge_NO']?.toString() ?? '';

    return FutureBuilder<String>(
      future: _getEditableValue(badgeNo, columnName),
      builder: (context, snapshot) {
        // Get the current value from the editable data service, fallback to record data
        String currentValue = snapshot.data ?? '';
        if (currentValue.isEmpty) {
          currentValue = record[columnName]?.toString() ?? '';
        }

        return InkWell(
          onTap: () => _showEditDialog(record, columnName, currentValue),
          child: Container(
            width: double.infinity,
            height: 40, // Fixed height to ensure visibility
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade300, width: 1),
              borderRadius: BorderRadius.circular(4),
              color: Colors.blue.shade50,
            ),
            child: Center(
              child: Text(
                currentValue.isEmpty ? 'انقر للتعديل' : currentValue,
                style: TextStyle(
                  fontSize: 12,
                  color: currentValue.isEmpty
                      ? Colors.grey.shade600
                      : Colors.blue.shade700,
                  fontStyle: currentValue.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownCell(Map<String, dynamic> record, String columnName) {
    final currentValue =
        _normalizeDropdownValue(record[columnName]?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: DropdownButton<String>(
        value: currentValue.isEmpty ? null : currentValue,
        hint: Text(
          'Select',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        isExpanded: true,
        underline: Container(), // Remove default underline
        icon: Icon(
          Icons.arrow_drop_down,
          color: Colors.blue.shade700,
        ),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
        items: const [
          DropdownMenuItem(
            value: 'Done',
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Done', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'Yes',
            child: Row(
              children: [
                Icon(Icons.thumb_up, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Text('Yes', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'No',
            child: Row(
              children: [
                Icon(Icons.thumb_down, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('No', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
        onChanged: (value) =>
            _handleDropdownChange(record, columnName, value ?? ''),
      ),
    );
  }

  void _handleRightClick(DataGridCell dataGridCell) {
    final cellValue = dataGridCell.value.toString();
    _clipboardValues.add(cellValue);
    final allValues = _clipboardValues.join('\n');
    Clipboard.setData(ClipboardData(text: allValues));
    onCopyCellContent?.call(
      'تم إضافة إلى الحافظة (${_clipboardValues.length} عنصر)',
    );
  }

  void _handleDoubleClick(DataGridCell dataGridCell) {
    _clipboardValues.clear();
    final cellValue = dataGridCell.value.toString();
    Clipboard.setData(ClipboardData(text: cellValue));
    onCopyCellContent?.call('تم نسخ: $cellValue');
  }

  void _showEditDialog(
    Map<String, dynamic> record,
    String fieldName,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل $fieldName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: fieldName,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null && _editableDataService != null) {
      final badgeNo = record['Badge_NO']?.toString() ?? '';
      final employeeName = record['Employee_Name']?.toString() ?? '';

      // Save to editable data service
      await _editableDataService!.saveEditableData(
        badgeNo: badgeNo,
        employeeName: employeeName,
        screenType: 'transfers',
        columnName: fieldName,
        value: result,
        timestamp: DateTime.now(),
      );

      // Update the record in the original data
      record[fieldName] = result;

      // Force rebuild data grid rows
      _buildDataGridRows();

      // Force notify listeners to refresh UI
      notifyListeners();

      // Add a small delay and notify again to ensure refresh
      Future.delayed(const Duration(milliseconds: 100), () {
        notifyListeners();
      });

      // Notify parent if callback is provided
      if (onUpdateField != null) {
        final sNo = record['S_NO']?.toString() ?? '';
        onUpdateField!(sNo, fieldName, result);
      }

      print('Data saved and refreshed for $fieldName: $result');
    }
  }

  // Add method to refresh data source
  void refreshDataSource() {
    _buildDataGridRows();
    notifyListeners();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final rowIndex = _dataGridRows.indexOf(row);

    // Safety check to prevent RangeError
    if (rowIndex < 0 || rowIndex >= _data.length) {
      // Return an empty row with proper cell count
      final cellCount = _columns.length + (onRemoveTransfer != null ? 1 : 0);
      return DataGridRowAdapter(
        cells: List.generate(cellCount, (index) => Container()),
      );
    }

    final record = _data[rowIndex];

    // Only build cells for visible columns (matching the _columns list)
    final cells = _columns.map<Widget>((column) {
      // Find the corresponding cell in the row
      final dataGridCell = row.getCells().firstWhere(
            (cell) => cell.columnName == column,
            orElse: () => DataGridCell(columnName: column, value: ''),
          );

      // Handle dropdown field (DONE_YES_NO)
      if (_isDropdownField(column)) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: _buildDropdownCell(record, column),
        );
      }

      // Handle editable fields
      if (_isFieldEditable(column)) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: _buildEditableCell(record, column),
        );
      }

      // Regular non-editable cell
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: Text(
          dataGridCell.value.toString(),
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }).toList();

    // Add delete button
    if (onRemoveTransfer != null) {
      cells.add(
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4.0),
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => onRemoveTransfer?.call(record),
            tooltip: 'حذف التنقل',
          ),
        ),
      );
    }

    return DataGridRowAdapter(
      color: rowIndex % 2 == 0 ? Colors.white : Colors.blue.shade50,
      cells: cells,
    );
  }

  Future<String> _getEditableValue(String badgeNo, String columnName) async {
    if (_editableDataService == null) return '';

    try {
      // First, check if this employee has a valid transfer record with basic data
      final currentRecord = _data.firstWhere(
        (item) => item['Badge_NO']?.toString() == badgeNo,
        orElse: () => <String, dynamic>{},
      );

      // If the transfer record is missing critical data, don't show old editable values
      if (currentRecord.isEmpty ||
          (currentRecord['Employee_Name']?.toString().isEmpty ?? true)) {
        print(
            'Transfer record for $badgeNo is incomplete, not showing old editable values');
        return '';
      }

      final editableData = await _editableDataService!.getEditableData(
        badgeNo: badgeNo,
        screenType: 'transfers',
      );
      return editableData[columnName] ?? '';
    } catch (e) {
      print('Error getting editable value: $e');
      return '';
    }
  }

  Future<void> _handleDropdownChange(
      Map<String, dynamic> record, String columnName, String value) async {
    final badgeNo = record['Badge_NO']?.toString() ?? '';
    final employeeName = record['Employee_Name']?.toString() ?? '';

    // Update the record
    record[columnName] = value;

    // Handle different dropdown values
    if (value == 'Done') {
      // Save the dropdown change first
      if (_editableDataService != null) {
        await _editableDataService!.saveEditableData(
          badgeNo: badgeNo,
          employeeName: employeeName,
          screenType: 'transfers',
          columnName: columnName,
          value: value,
          timestamp: DateTime.now(),
        );
      }

      // Then transfer to transferred screen directly without confirmation
      if (onTransferEmployee != null) {
        onTransferEmployee!(
            record); // This will remove the record from the list
        // No need to rebuild here since the record is being removed
        return; // Exit early since the record is being transferred
      } else {
        // Fallback to the old method if callback not provided
        await _transferEmployee(record);
        return; // Exit early since the record is being transferred
      }
    } else if (value == 'No') {
      // Delete this employee (this will show confirmation)
      onRemoveTransfer?.call(record);
      return; // Exit early since the record might be removed
    }

    // Save to editable data service (for other values like 'Yes')
    if (_editableDataService != null) {
      await _editableDataService!.saveEditableData(
        badgeNo: badgeNo,
        employeeName: employeeName,
        screenType: 'transfers',
        columnName: columnName,
        value: value,
        timestamp: DateTime.now(),
      );
    }

    // Rebuild data grid rows (only for values that don't remove the record)
    _buildDataGridRows();
    notifyListeners();
  }

  Future<void> _transferEmployee(Map<String, dynamic> record) async {
    if (_editableDataService == null) return;

    try {
      final badgeNo = record['Badge_NO']?.toString() ?? '';
      await _editableDataService!.transferEmployeeToTransferred(
        badgeNo: badgeNo,
        transferData: record,
      );

      // Remove from current transfers list
      onRemoveTransfer?.call(record);

      // Show success message
      onCopyCellContent?.call('تم نقل الموظف إلى شاشة المنقولين بنجاح');
    } catch (e) {
      print('Error transferring employee: $e');
      onCopyCellContent?.call('خطأ في نقل الموظف: $e');
    }
  }
}
