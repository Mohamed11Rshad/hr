import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PromotionCalculationService {
  final Database db;

  PromotionCalculationService(this.db);

  Future<Map<String, dynamic>> calculatePromotionData(
    Map<String, dynamic> record,
  ) async {
    // Create a completely new mutable map to avoid read-only issues
    final newRecord = <String, dynamic>{};

    // Copy all existing data to the new mutable map
    record.forEach((key, value) {
      newRecord[key] = value;
    });

    // Calculate Next Grade
    final nextGrade = _calculateNextGrade(record['Grade']?.toString() ?? '');
    newRecord['Next_Grade'] = nextGrade;

    // Calculate 4% Adjustment - format as integer
    final oldBasic = double.tryParse(record['Basic']?.toString() ?? '0') ?? 0;
    final fourPercentAdj = oldBasic * 0.04;
    newRecord['4% Adj'] = fourPercentAdj.round().toString();

    // Calculate Annual Increment - format as integer
    final annualIncrement = await _calculateAnnualIncrement(
      record,
      nextGrade,
      oldBasic,
      fourPercentAdj,
    );
    newRecord['Annual_Increment'] = annualIncrement.round().toString();

    // Calculate New Basic - format as integer
    final newBasic = oldBasic + fourPercentAdj + annualIncrement;
    newRecord['New_Basic'] = newBasic.round().toString();

    return newRecord;
  }

  String _calculateNextGrade(String gradeValue) {
    if (gradeValue.isEmpty) return '';

    try {
      final gradeInt =
          int.tryParse(gradeValue.replaceAll(RegExp(r'^0+'), '')) ?? 0;
      return (gradeInt + 1).toString();
    } catch (e) {
      return gradeValue;
    }
  }

  Future<double> _calculateAnnualIncrement(
    Map<String, dynamic> record,
    String nextGrade,
    double oldBasic,
    double fourPercentAdj,
  ) async {
    debugPrint("8888888888888888888888 nextGrade: $nextGrade");

    final adjustedEligibleDate =
        record['Adjusted_Eligible_Date']?.toString() ?? '';

    if (adjustedEligibleDate.isEmpty) return 0;

    try {
      final date = _parseDate(adjustedEligibleDate);

      // Check if it's January 1st
      if (date.month != 1 || date.day != 1) return 0;

      // Determine which tables to use
      final payScaleArea = record['pay_scale_area_text']?.toString() ?? '';
      final salaryScaleTable =
          payScaleArea.contains('Category B')
              ? 'Salary_Scale_B'
              : 'Salary_Scale_A';
      final annualIncreaseTable =
          payScaleArea.contains('Category B')
              ? 'Annual_Increase_B'
              : 'Annual_Increase_A';

      debugPrint("8888888888888888888888 salaryScaleTable: $salaryScaleTable");

      // Get salary scale data
      final salaryScaleData = await db.query(
        salaryScaleTable,
        where: 'Grade = ?',
        whereArgs: [nextGrade],
      );

      if (salaryScaleData.isEmpty) return 0;

      final midpoint =
          double.tryParse(
            salaryScaleData.first['midpoint']?.toString() ?? '0',
          ) ??
          0;
      final maximum =
          double.tryParse(
            salaryScaleData.first['maximum']?.toString() ?? '0',
          ) ??
          0;

      // Determine midpoint status
      final oldBasePlusAdj = oldBasic + fourPercentAdj;
      final midpointStatus = (oldBasePlusAdj < midpoint) ? 'b' : 'a';

      debugPrint("8888888888888888888888 midpointStatus: $midpointStatus");

      // Get annual increase data
      var appraisalValue =
          record['Appraisal5']?.toString().split('-')[1].replaceAll('+', 'p') ??
          '';
      final annualIncreaseData = await db.query(
        annualIncreaseTable,
        where: 'Grade = ?',
        whereArgs: [nextGrade],
      );

      debugPrint("8888888888888888888888 appraisalValue: $appraisalValue");

      if (annualIncreaseData.isEmpty) return 0;

      final potentialIncrement =
          double.tryParse(
            annualIncreaseData.first['${appraisalValue}_$midpointStatus']
                    ?.toString() ??
                '0',
          ) ??
          0;

      debugPrint(
        "8888888888888888888888 ${annualIncreaseData.first['${appraisalValue}_$midpointStatus']?.toString()}",
      );

      debugPrint(
        "8888888888888888888888 potentialIncrement: ${appraisalValue}_$midpointStatus",
      );

      // Apply maximum limit and return as double (will be rounded in calculatePromotionData)
      return (potentialIncrement + oldBasePlusAdj) > maximum
          ? (maximum - oldBasePlusAdj)
          : (potentialIncrement < 0 ? 0 : potentialIncrement);
    } catch (e) {
      print('Error calculating annual increment: $e');
      return 0;
    }
  }

  DateTime _parseDate(String dateString) {
    if (dateString.contains('.')) {
      final parts = dateString.split('.');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } else if (dateString.contains('/')) {
      final parts = dateString.split('/');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } else {
      return DateTime.parse(dateString);
    }
  }
}
