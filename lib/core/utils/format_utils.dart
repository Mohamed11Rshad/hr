class FormatUtils {
  /// Formats a string value as integer for display
  static String formatAsInteger(String value) {
    if (value.isEmpty) return '';
    
    try {
      final doubleValue = double.tryParse(value) ?? 0;
      return doubleValue.round().toString();
    } catch (e) {
      return value;
    }
  }
  
  /// Formats a date string for display
  static String formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }
  
  /// Parses various date formats
  static DateTime parseDate(String dateString) {
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
  
  /// Generates upload date with custom format
  static String generateUploadDate() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    return '${now.year}-${now.month}-${now.day} $hour:${now.minute.toString().padLeft(2, '0')}${now.hour >= 12 ? "pm" : "am"}';
  }
  
  /// Removes leading zeros from grade strings
  static String normalizeGrade(String grade) {
    return grade.replaceAll(RegExp(r'^0+'), '');
  }
}
