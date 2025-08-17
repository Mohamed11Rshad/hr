class CategoryMapper {
  static const Map<String, Map<String, String>> categoryMapping = {
    'Category A': {
      'salaryScale': 'Salary_Scale_A',
      'annualIncrease': 'Annual_Increase_A',
    },
    'Category B': {
      'salaryScale': 'Salary_Scale_B',
      'annualIncrease': 'Annual_Increase_B',
    },
    'Category D plus': {
      'salaryScale': 'Salary_Scale_D_plus',
      'annualIncrease': 'Annual_Increase_D_plus',
    },
    'SNR-PMSS Category A': {
      'salaryScale': 'Salary_Scale_SNR_PMSS_A',
      'annualIncrease': 'Annual_Increase_SNR_PMSS_A',
    },
    'SNR-PMSS Category B': {
      'salaryScale': 'Salary_Scale_SNR_PMSS_B',
      'annualIncrease': 'Annual_Increase_SNR_PMSS_B',
    },
    'JNR-PMSS': {
      'salaryScale': 'Salary_Scale_JNR_PMSS',
      'annualIncrease': 'Annual_Increase_JNR_PMSS',
    },
    'PMSS Daily Rates': {
      'salaryScale': 'Salary_Scale_PMSS_Daily_Rates',
      'annualIncrease': 'Annual_Increase_PMSS_Daily',
    },
  };

  // Map Excel sheet names (with spaces) to table names (with underscores)
  static const Map<String, String> sheetToTableMapping = {
    'Salary Scale A': 'Salary_Scale_A',
    'Salary Scale B': 'Salary_Scale_B',
    'Salary Scale D plus': 'Salary_Scale_D_plus',
    'Salary Scale SNR-PMSS A': 'Salary_Scale_SNR_PMSS_A',
    'Salary Scale SNR-PMSS B': 'Salary_Scale_SNR_PMSS_B',
    'Salary Scale JNR-PMSS': 'Salary_Scale_JNR_PMSS',
    'Salary Scale PMSS Daily Rates': 'Salary_Scale_PMSS_Daily_Rates',
    'Annual Increase A': 'Annual_Increase_A',
    'Annual Increase B': 'Annual_Increase_B',
    'Annual Increase D plus': 'Annual_Increase_D_plus',
    'Annual Increase SNR-PMSS A': 'Annual_Increase_SNR_PMSS_A',
    'Annual Increase SNR-PMSS B': 'Annual_Increase_SNR_PMSS_B',
    'Annual Increase JNR-PMSS': 'Annual_Increase_JNR_PMSS',
    'Annual Increase PMSS Daily': 'Annual_Increase_PMSS_Daily',
  };

  /// Convert Excel sheet name to database table name
  static String getTableNameFromSheet(String sheetName) {
    return sheetToTableMapping[sheetName] ?? sheetName.replaceAll(' ', '_');
  }

  /// Get salary scale table name for a given category
  static String getSalaryScaleTable(String payScaleArea) {
    // Clean the category name
    final cleanCategory = payScaleArea.trim();

    // Look for exact match first
    if (categoryMapping.containsKey(cleanCategory)) {
      return categoryMapping[cleanCategory]!['salaryScale']!;
    }

    // Look for partial matches for backward compatibility
    for (final category in categoryMapping.keys) {
      if (cleanCategory.contains(category)) {
        return categoryMapping[category]!['salaryScale']!;
      }
    }

    // Default fallback to Category A
    return 'Salary_Scale_A';
  }

  /// Get annual increase table name for a given category
  static String getAnnualIncreaseTable(String payScaleArea) {
    // Clean the category name
    final cleanCategory = payScaleArea.trim();

    // Look for exact match first
    if (categoryMapping.containsKey(cleanCategory)) {
      return categoryMapping[cleanCategory]!['annualIncrease']!;
    }

    // Look for partial matches for backward compatibility
    for (final category in categoryMapping.keys) {
      if (cleanCategory.contains(category)) {
        return categoryMapping[category]!['annualIncrease']!;
      }
    }

    // Default fallback to Category A
    return 'Annual_Increase_A';
  }

  /// Get all available categories
  static List<String> getAllCategories() {
    return categoryMapping.keys.toList();
  }

  /// Check if a category is valid
  static bool isValidCategory(String category) {
    return categoryMapping.containsKey(category.trim());
  }
}
