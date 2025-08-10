class TableConstants {
  // Table names
  static const String baseSheet = 'Base_Sheet';
  static const String promotions = 'promotions';
  static const String promotedEmployees = 'promoted_employees';
  static const String transfers = 'transfers';
  static const String status = 'Status';
  static const String salaryScaleA = 'Salary_Scale_A';
  static const String salaryScaleB = 'Salary_Scale_B';
  static const String annualIncreaseA = 'Annual_Increase_A';
  static const String annualIncreaseBr = 'Annual_Increase_B';
  static const String staffAssignments =
      'Staff Assignments'; // Updated to reflect the new sheet name

  // Internal tables (excluded from user operations)
  static const Set<String> internalTables = {
    promotedEmployees,
    promotions,
    transfers,
  };

  // Config tables required for promotions
  static const List<String> requiredPromotionTables = [
    salaryScaleA,
    salaryScaleB,
    annualIncreaseA,
    annualIncreaseBr,
    status,
  ];

  // Badge column variations
  static const List<String> badgeColumnVariations = [
    'Badge_NO',
    'Badge_No',
    'badge_no',
    'badge_number',
    'BadgeNo',
  ];

  // Employee name column variations
  static const List<String> employeeNameVariations = [
    'Employee_Name',
    'Employee_name',
    'employee_name',
    'EmployeeName',
    'Name',
  ];
}
