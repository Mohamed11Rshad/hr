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
    // Add new remaining columns with display names
    'Age__Hijra_': 'Age (Hijra)',
    'Age__Gregorian_': 'Age (Gregorian)',
    'OrgUnit4': 'Org Unit 4',
    'Position_Abbrv': 'Position Code',
    'Certificate': 'Certificate',
    'Date_of_Join': 'Join Date',
    'Educational_Est': 'Educational Est',
    'Institute_Location': 'Institute Location',
    'Nationality': 'Nationality',
    'Service_in_KJO': 'Service in KJO',
    'Period_Since_Last_Promotion': 'Period Since Last Promotion',
    'Due_Date': 'Due Date',
    'Calculated_Year_for_Promotion': 'Calculated Year for Promotion',
    'Recommended_Date': 'Recommended Date',
    'Eligible_Date': 'Eligible Date',
    'Appraisal1': 'Appraisal 1',
    'Appraisal2': 'Appraisal 2',
    'Appraisal3': 'Appraisal 3',
    'Appraisal4': 'Appraisal 4',
    'Appraisal5': 'Appraisal 5',
    'GAP': 'GAP',
    'Meet_Requirement': 'Meet Requirement',
    'Missing_criteria': 'Missing Criteria',
    'OrgUnit1': 'Org Unit 1',
    'Retirement_Date__Grego_': 'Retirement Date (Gregorian)',
    'Pay_scale_area_text': 'Pay Scale Area',
  };

  static const Map<String, String> promotedColumnNames = {
    'Badge_NO': 'Badge ID',
    'Employee_Name': 'Name',
    'Grade': 'Grade',
    'Status': 'Status',
    'Last_Promotion_Dt':
        'Last Prom Date', // Updated to reflect that this now contains the adjusted eligible date
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
