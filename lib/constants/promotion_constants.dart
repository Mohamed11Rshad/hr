class PromotionConstants {
  static const Map<String, String> columnNames = {
    'Badge_NO': 'Badge ID',
    'Employee_Name': 'Name',
    'Bus_Line': 'Business Line',
    'Depart_Text': 'Department',
    'Status': 'Status',
    'Grade': 'Grade',
    'Adjusted_Eligible_Date': 'Adjus Elig',
    'Basic': 'Old Basic',
    'Next_Grade': 'Next Grade',
    '4% Adj': '4% Adj',
    'Annual_Increment': 'Annual Increment',
    'New_Basic': 'New Basic',
    'Position_Text': 'Position',
    'Grade_Range': 'Grade Range',
    'Promotion_Band': 'Promotion Band',
    'Prom_Reason': 'Prom Reason',
    'Last_Promotion_Dt': 'Last Promotion',
  };

  static const Map<String, String> promotedColumnNames = {
    'Badge_NO': 'Badge ID',
    'Employee_Name': 'Name',
    'Grade': 'Grade',
    'Status': 'Status',
    'Adjusted_Eligible_Date': 'Adj Elig Date',
    'Last_Promotion_Dt': 'Last Prom Date',
    'Prom_Reason': 'Prom Reason',
    'promoted_date': 'Action Date',
  };

  static const List<String> requiredColumns = [
    'Badge_NO',
    'Employee_Name',
    'Bus_Line',
    'Depart_Text',
    'Status', // Add Status before Grade
    'Grade',
    'Adjusted_Eligible_Date',
    'Basic',
    'Next_Grade',
    '4% Adj',
    'Annual_Increment',
    'New_Basic',
    'Position_Text',
    'Grade_Range',
    'Promotion_Band',
    'Prom_Reason',
    'Last_Promotion_Dt',
  ];

  static const int pageSize = 100;
}
