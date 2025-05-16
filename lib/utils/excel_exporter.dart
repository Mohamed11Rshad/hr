import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class ExcelExporter {
  static Future<void> exportToExcel({
    required BuildContext context,
    required List<Map<String, dynamic>> data,
    required List<String> columns,
    required Map<String, String> columnNames,
    required String tableName,
  }) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للتحميل')));
      return;
    }

    try {
      // Create a new Excel file
      final excel = Excel.createExcel();
      final sheet = excel.sheets[excel.getDefaultSheet()!]!;

      // Add headers (first row)
      final visibleColumns =
          columns
              .where(
                (column) => !column.endsWith('_highlighted') && column != 'id',
              )
              .toList();

      for (int i = 0; i < visibleColumns.length; i++) {
        final column = visibleColumns[i];
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(columnNames[column] ?? column);
        // Style the header
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString(
            '#4472C4',
          ), // Blue background
          fontColorHex: ExcelColor.fromHexString('#FFFFFFFF'), // White text
        );
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        final record = data[rowIndex];

        for (int colIndex = 0; colIndex < visibleColumns.length; colIndex++) {
          final column = visibleColumns[colIndex];
          final value = record[column]?.toString() ?? '';

          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex + 1, // +1 because row 0 is the header
            ),
          );

          cell.value = TextCellValue(value);

          // Check if this cell was highlighted in the UI
          final isHighlighted = record['${column}_highlighted'] == true;
          if (isHighlighted) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString(
                '#FFFF00',
              ), // Yellow background for highlighted cells
            );
          }
        }
      }

      // Auto-fit columns
      for (int i = 0; i < visibleColumns.length; i++) {
        sheet.setColumnWidth(i, 20); // Set a reasonable default width
      }

      // Generate default file name
      final now = DateTime.now();
      final fileName =
          '${tableName}_${now.year}${now.month}${now.day}_${now.hour}${now.minute}.xlsx';

      // Let user select save location
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputPath == null) {
        // User cancelled the picker
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إلغاء تحميل الملف')));
        return;
      }

      // Ensure the file has .xlsx extension
      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath += '.xlsx';
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(outputPath);
        await file.writeAsBytes(fileBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحميل الملف بنجاح إلى: $outputPath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الملف: ${e.toString()}')),
      );
    }
  }
}
