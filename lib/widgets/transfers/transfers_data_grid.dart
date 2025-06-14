import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/constants/transfers_constants.dart';
import 'package:hr/widgets/transfers/transfers_data_source.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class TransfersDataGrid extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final Set<String> hiddenColumns;
  final Function(Map<String, dynamic>) onRemoveTransfer;
  final Function(String, String, String) onUpdateField;
  final Function(String) onCopyCellContent;

  const TransfersDataGrid({
    Key? key,
    required this.data,
    required this.hiddenColumns,
    required this.onRemoveTransfer,
    required this.onUpdateField,
    required this.onCopyCellContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataSource = TransfersDataSource(
      data,
      TransfersConstants.columns
          .where((col) => !hiddenColumns.contains(col))
          .toList(),
      context: context,
      onRemoveTransfer: onRemoveTransfer,
      onUpdateField: onUpdateField,
      onCopyCellContent: onCopyCellContent,
    );

    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: AppColors.primaryColor,
        gridLineColor: Colors.grey.shade300,
        gridLineStrokeWidth: 1.0,
        selectionColor: Colors.grey.shade400,
        filterIconColor: Colors.white,
        sortIconColor: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SfDataGrid(
          source: dataSource,
          columnWidthMode: ColumnWidthMode.fill, // Changed to fill
          columnWidthCalculationRange: ColumnWidthCalculationRange.allRows,
          allowSorting: true,
          allowFiltering: true,
          selectionMode: SelectionMode.single,
          showHorizontalScrollbar: true,
          showVerticalScrollbar: true,
          isScrollbarAlwaysShown: true,
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          rowHeight: 60,
          headerRowHeight: 65,
          columns: _buildGridColumns(),
        ),
      ),
    );
  }

  List<GridColumn> _buildGridColumns() {
    final columns =
        TransfersConstants.columns
            .where((col) => !hiddenColumns.contains(col))
            .map((column) {
              double minWidth = _getColumnWidth(
                column,
              ); // Add back minimum width

              return GridColumn(
                columnName: column,
                minimumWidth: minWidth, // Restore minimum width
                autoFitPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: Text(
                    TransfersConstants.columnNames[column] ?? column,
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
            })
            .toList();

    // Add delete action column
    columns.add(
      GridColumn(
        columnName: 'actions',
        columnWidthMode: ColumnWidthMode.auto,
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

    return columns;
  }

  // Restore the _getColumnWidth method
  double _getColumnWidth(String column) {
    switch (column) {
      case 'S_NO':
        return 120;
      case 'Badge_NO':
        return 160;
      case 'Employee_Name':
      case 'Position_Description':
      case 'OrgUnit_Description':
      case 'Occupancy':
      case 'Bus_Line':
      case 'Depart_Text':
      case 'Position_Text':
      case 'Emp_Position_Code':
      case 'New_Bus_Line': // Add width for new column
        return 220;
      case 'Grade':
      case 'Position_Abbreviation':
      case 'Dept':
      case 'Badge_Number':
        return 180;
      case 'Grade_Range':
      case 'Grade_Range6':
      case 'Grade_GAP':
      case 'Transfer_Type':
        return 180;
      case 'POD':
      case 'ERD':
      case 'DONE_YES_NO':
      case 'Available_in_ERD':
        return 200;
      default:
        return 140.0;
    }
  }
}
