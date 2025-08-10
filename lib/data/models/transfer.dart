import '../../core/enums/data_operation_type.dart';

class Transfer {
  final int? sNo;
  final String badgeNo;
  final String positionCode;
  final String? pod;
  final String? erd;
  final String? doneYesNo;
  final String? availableInErd;
  final String? createdDate;
  final String? employeeName;
  final String? busLine;
  final String? department;
  final String? grade;
  final String? gradeRange;
  final String? position;
  final String? newBusLine;
  final String? dept;
  final String? positionAbbreviation;
  final String? positionDescription;
  final String? orgUnitDescription;
  final String? gradeRange6;
  final String? occupancy;
  final String? badgeNumber;
  final String? gradeGap;
  final TransferType? transferType;

  Transfer({
    this.sNo,
    required this.badgeNo,
    required this.positionCode,
    this.pod,
    this.erd,
    this.doneYesNo,
    this.availableInErd,
    this.createdDate,
    this.employeeName,
    this.busLine,
    this.department,
    this.grade,
    this.gradeRange,
    this.position,
    this.newBusLine,
    this.dept,
    this.positionAbbreviation,
    this.positionDescription,
    this.orgUnitDescription,
    this.gradeRange6,
    this.occupancy,
    this.badgeNumber,
    this.gradeGap,
    this.transferType,
  });

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      sNo: map['S_NO'] as int?,
      badgeNo: map['Badge_NO']?.toString() ?? '',
      positionCode: map['Position_Code']?.toString() ?? '',
      pod: map['POD']?.toString(),
      erd: map['ERD']?.toString(),
      doneYesNo: map['DONE_YES_NO']?.toString(),
      availableInErd: map['Available_in_ERD']?.toString(),
      createdDate: map['created_date']?.toString(),
      employeeName: map['Employee_Name']?.toString(),
      busLine: map['Bus_Line']?.toString(),
      department: map['Depart_Text']?.toString(),
      grade: map['Grade']?.toString(),
      gradeRange: map['Grade_Range']?.toString(),
      position: map['Position_Text']?.toString(),
      newBusLine: map['New_Bus_Line']?.toString(),
      dept: map['Dept']?.toString(),
      positionAbbreviation: map['Position_Abbreviation']?.toString(),
      positionDescription: map['Position_Description']?.toString(),
      orgUnitDescription: map['OrgUnit_Description']?.toString(),
      gradeRange6: map['Grade_Range6']?.toString(),
      occupancy: map['Occupancy']?.toString(),
      badgeNumber: map['Badge_Number']?.toString(),
      gradeGap: map['Grade_GAP']?.toString(),
      transferType: _parseTransferType(map['Transfer_Type']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (sNo != null) 'S_NO': sNo,
      'Badge_NO': badgeNo,
      'Position_Code': positionCode,
      'POD': pod,
      'ERD': erd,
      'DONE_YES_NO': doneYesNo,
      'Available_in_ERD': availableInErd,
      'created_date': createdDate,
      'Employee_Name': employeeName,
      'Bus_Line': busLine,
      'Depart_Text': department,
      'Grade': grade,
      'Grade_Range': gradeRange,
      'Position_Text': position,
      'New_Bus_Line': newBusLine,
      'Dept': dept,
      'Position_Abbreviation': positionAbbreviation,
      'Position_Description': positionDescription,
      'OrgUnit_Description': orgUnitDescription,
      'Grade_Range6': gradeRange6,
      'Occupancy': occupancy,
      'Badge_Number': badgeNumber,
      'Grade_GAP': gradeGap,
      'Transfer_Type': _transferTypeToString(transferType),
    };
  }

  static TransferType? _parseTransferType(String? value) {
    switch (value?.toLowerCase()) {
      case 'higher band':
        return TransferType.higherBand;
      case 'lower band':
        return TransferType.lowerBand;
      case 'same band':
        return TransferType.sameBand;
      default:
        return null;
    }
  }

  static String? _transferTypeToString(TransferType? type) {
    switch (type) {
      case TransferType.higherBand:
        return 'Higher Band';
      case TransferType.lowerBand:
        return 'Lower Band';
      case TransferType.sameBand:
        return 'Same Band';
      default:
        return null;
    }
  }
}
