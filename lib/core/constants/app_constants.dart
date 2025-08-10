class AppConstants {
  // Database constants
  static const String databaseName = 'hr_database.db';
  static const int databaseVersion = 1;
  
  // Pagination constants
  static const int defaultPageSize = 80;
  static const int promotionPageSize = 50;
  
  // File processing constants
  static const int excelChunkSize = 500;
  static const Duration processingDelay = Duration(milliseconds: 50);
  
  // Animation constants
  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // Validation constants
  static const int maxPromReasonLength = 200;
  static const List<String> supportedFileExtensions = ['xlsx', 'xls'];
  
  // UI constants
  static const double defaultColumnWidth = 180.0;
  static const double minColumnWidth = 20.0;
  static const double actionColumnWidth = 100.0;
}
