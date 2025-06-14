class TransfersConstants {
  static const List<String> columns = [
    'S_NO',
    'Badge_NO',
    'Employee_Name',
    'Bus_Line',
    'Depart_Text',
    'Grade',
    'Grade_Range',
    'Emp_Position_Code',
    'Position_Text',
    // Staff Assignments columns
    'New_Bus_Line',
    'Dept',
    'Position_Abbreviation',
    'Position_Description',
    // Add new column after Position_Description
    'OrgUnit_Description',
    'Grade_Range6',
    'Occupancy',
    'Badge_Number',
    'Grade_GAP', // Add new column after Badge_Number
    // Editable columns
    'POD',
    'ERD',
    'Transfer_Type', // Add new column after ERD
    'DONE_YES_NO',
    'Available_in_ERD',
  ];

  static const Map<String, String> columnNames = {
    'S_NO': 'S.NO',
    'Badge_NO': 'Badge No',
    'Employee_Name': 'Employee Name',
    'Bus_Line': 'Business Line',
    'Depart_Text': 'Department',
    'Grade': 'Grade',
    'Grade_Range': 'Grade Range',
    'Emp_Position_Code': 'Emp Position Code',
    'Position_Text': 'Position',
    // Staff Assignments columns
    'New_Bus_Line': 'Bus Line', // Add display name for new column
    'Dept': 'Dept',
    'Position_Abbreviation': 'Position Code',
    'Position_Description': 'Position Name',
    'OrgUnit_Description': 'OrgUnit Name',
    'Grade_Range6': 'Grade Range6',
    'Occupancy': 'Occupied By Type',
    'Badge_Number': 'Occupied By',
    'Grade_GAP': 'Grade GAP', // Add display name for new column
    // Editable columns
    'POD': 'POD',
    'ERD': 'ERD',
    'Transfer_Type': 'Transfer Type', // Add display name for new column
    'DONE_YES_NO': 'Done/Yes/No',
    'Available_in_ERD': 'Available in ERD',
  };

  static const List<String> editableColumns = [
    'POD',
    'ERD',
    'DONE_YES_NO',
    'Available_in_ERD',
  ];
}
