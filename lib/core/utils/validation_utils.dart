import '../constants/table_constants.dart';

class ValidationUtils {
  /// Finds the badge column name from a list of columns
  static String findBadgeColumn(List<String> columns) {
    for (final variation in TableConstants.badgeColumnVariations) {
      final found = columns.firstWhere(
        (col) => col.toLowerCase() == variation.toLowerCase(),
        orElse: () => '',
      );
      if (found.isNotEmpty) return found;
    }

    // Fallback to any column containing 'badge'
    return columns.firstWhere(
      (col) => col.toLowerCase().contains('badge'),
      orElse: () => 'Badge_NO',
    );
  }

  /// Finds the employee name column from a list of columns
  static String findEmployeeNameColumn(List<String> columns) {
    for (final variation in TableConstants.employeeNameVariations) {
      final found = columns.firstWhere(
        (col) => col.toLowerCase() == variation.toLowerCase(),
        orElse: () => '',
      );
      if (found.isNotEmpty) return found;
    }

    // Fallback to any column containing 'name'
    return columns.firstWhere(
      (col) => col.toLowerCase().contains('name'),
      orElse: () => 'Employee_Name',
    );
  }

  /// Validates if a badge number format is correct
  static bool isValidBadgeNumber(String badgeNo) {
    if (badgeNo.trim().isEmpty) return false;

    // Check if it's a valid number (can contain leading zeros)
    final numericPart = badgeNo.replaceAll(RegExp(r'^0+'), '');
    return int.tryParse(numericPart) != null;
  }

  /// Validates if a salary value is within acceptable range
  static bool isValidSalary(
    double salary, {
    double minSalary = 0,
    double maxSalary = 1000000,
  }) {
    return salary >= minSalary && salary <= maxSalary;
  }

  /// Validates if an email format is correct
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Sanitizes column names for database use
  static String sanitizeColumnName(String name) {
    String sanitized = name
        .replaceAll(' ', '_')
        .replaceAll('.', '_')
        .replaceAll('-', '_')
        .replaceAll('(', '_')
        .replaceAll(')', '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('+', '_')
        .replaceAll('&', '_')
        .replaceAll('%', '_');

    // Ensure name doesn't start with a number
    if (RegExp(r'^[0-9]').hasMatch(sanitized)) {
      sanitized = 'col_$sanitized';
    }

    return sanitized;
  }

  /// Escapes column names for SQL queries
  static String escapeColumnName(String name) {
    return '"${sanitizeColumnName(name)}"';
  }

  /// Validates if a date string is in correct format and represents a valid date
  static bool isValidDate(String dateString) {
    if (dateString.trim().isEmpty) return true; // Allow empty dates

    try {
      // Check for DD.MM.YYYY format
      if (dateString.contains('.')) {
        final parts = dateString.split('.');
        if (parts.length != 3) return false;

        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day == null || month == null || year == null) return false;
        if (day < 1 || day > 31) return false;
        if (month < 1 || month > 12) return false;
        if (year < 1900 || year > 2100) return false;

        // Try to create actual date to validate day/month combination
        final date = DateTime(year, month, day);
        return date.day == day && date.month == month && date.year == year;
      }

      // Check for DD/MM/YYYY format
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length != 3) return false;

        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day == null || month == null || year == null) return false;
        if (day < 1 || day > 31) return false;
        if (month < 1 || month > 12) return false;
        if (year < 1900 || year > 2100) return false;

        // Try to create actual date to validate day/month combination
        final date = DateTime(year, month, day);
        return date.day == day && date.month == month && date.year == year;
      }

      // Try parsing as ISO format
      DateTime.parse(dateString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets error message for invalid date
  static String getDateValidationError(String dateString) {
    if (dateString.trim().isEmpty) return '';

    if (!dateString.contains('.') && !dateString.contains('/')) {
      return 'يجب أن يكون التاريخ بصيغة: يوم.شهر.سنة (مثال: 15.03.2024)';
    }

    final parts = dateString.split(dateString.contains('.') ? '.' : '/');
    if (parts.length != 3) {
      return 'يجب أن يكون التاريخ بصيغة: يوم.شهر.سنة (مثال: 15.03.2024)';
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return 'يجب أن تكون أجزاء التاريخ أرقام صحيحة';
    }

    if (day < 1 || day > 31) {
      return 'اليوم يجب أن يكون بين 1 و 31';
    }

    if (month < 1 || month > 12) {
      return 'الشهر يجب أن يكون بين 1 و 12';
    }

    if (year < 1900 || year > 2100) {
      return 'السنة يجب أن تكون بين 1900 و 2100';
    }

    try {
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) {
        return 'التاريخ غير صحيح (مثال: 31.02.2024 غير صالح)';
      }
    } catch (e) {
      return 'التاريخ غير صالح';
    }

    return '';
  }
}
