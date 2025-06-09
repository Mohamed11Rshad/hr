class PromotionEmployee {
  final String badgeNo;
  final String? employeeName;
  final String? businessLine;
  final String? department;
  final String? grade;
  final String? status;
  final String? adjustedEligibleDate;
  final String? promReason;
  final double? basic;
  final String? nextGrade;
  final double? fourPercentAdj;
  final double? annualIncrement;
  final double? newBasic;
  final String? position;
  final String? gradeRange;
  final String? promotionBand;
  final String? lastPromotionDate;

  PromotionEmployee({
    required this.badgeNo,
    this.employeeName,
    this.businessLine,
    this.department,
    this.grade,
    this.status,
    this.adjustedEligibleDate,
    this.promReason,
    this.basic,
    this.nextGrade,
    this.fourPercentAdj,
    this.annualIncrement,
    this.newBasic,
    this.position,
    this.gradeRange,
    this.promotionBand,
    this.lastPromotionDate,
  });

  factory PromotionEmployee.fromMap(Map<String, dynamic> map) {
    return PromotionEmployee(
      badgeNo: map['Badge_NO']?.toString() ?? '',
      employeeName: map['Employee_Name']?.toString(),
      businessLine: map['Bus_Line']?.toString(),
      department: map['Depart_Text']?.toString(),
      grade: map['Grade']?.toString(),
      status: map['Status']?.toString(),
      adjustedEligibleDate: map['Adjusted_Eligible_Date']?.toString(),
      promReason: map['Prom_Reason']?.toString(),
      basic: double.tryParse(map['Basic']?.toString() ?? '0'),
      nextGrade: map['Next_Grade']?.toString(),
      fourPercentAdj: double.tryParse(map['4% Adj']?.toString() ?? '0'),
      annualIncrement: double.tryParse(
        map['Annual_Increment']?.toString() ?? '0',
      ),
      newBasic: double.tryParse(map['New_Basic']?.toString() ?? '0'),
      position: map['Position_Text']?.toString(),
      gradeRange: map['Grade_Range']?.toString(),
      promotionBand: map['Promotion_Band']?.toString(),
      lastPromotionDate: map['Last_Promotion_Dt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Badge_NO': badgeNo,
      'Employee_Name': employeeName,
      'Bus_Line': businessLine,
      'Depart_Text': department,
      'Grade': grade,
      'Status': status,
      'Adjusted_Eligible_Date': adjustedEligibleDate,
      'Prom_Reason': promReason,
      'Basic': basic?.toString(),
      'Next_Grade': nextGrade,
      '4% Adj': fourPercentAdj?.toStringAsFixed(2),
      'Annual_Increment': annualIncrement?.toStringAsFixed(2),
      'New_Basic': newBasic?.toStringAsFixed(2),
      'Position_Text': position,
      'Grade_Range': gradeRange,
      'Promotion_Band': promotionBand,
      'Last_Promotion_Dt': lastPromotionDate,
    };
  }
}
