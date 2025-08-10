class Employee {
  final String badgeNo;
  final String? employeeName;
  final String? businessLine;
  final String? department;
  final String? grade;
  final String? status;
  final String? position;
  final double? basic;
  final String? gradeRange;
  final String? lastPromotionDate;
  final String? uploadDate;
  final int? id;

  Employee({
    required this.badgeNo,
    this.employeeName,
    this.businessLine,
    this.department,
    this.grade,
    this.status,
    this.position,
    this.basic,
    this.gradeRange,
    this.lastPromotionDate,
    this.uploadDate,
    this.id,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      badgeNo: map['Badge_NO']?.toString() ?? '',
      employeeName: map['Employee_Name']?.toString(),
      businessLine: map['Bus_Line']?.toString(),
      department: map['Depart_Text']?.toString(),
      grade: map['Grade']?.toString(),
      status: map['Status']?.toString(),
      position: map['Position_Text']?.toString(),
      basic: double.tryParse(map['Basic']?.toString() ?? '0'),
      gradeRange: map['Grade_Range']?.toString(),
      lastPromotionDate: map['Last_Promotion_Dt']?.toString(),
      uploadDate: map['upload_date']?.toString(),
      id: map['id'] as int?,
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
      'Position_Text': position,
      'Basic': basic?.toString(),
      'Grade_Range': gradeRange,
      'Last_Promotion_Dt': lastPromotionDate,
      'upload_date': uploadDate,
      if (id != null) 'id': id,
    };
  }

  Employee copyWith({
    String? badgeNo,
    String? employeeName,
    String? businessLine,
    String? department,
    String? grade,
    String? status,
    String? position,
    double? basic,
    String? gradeRange,
    String? lastPromotionDate,
    String? uploadDate,
    int? id,
  }) {
    return Employee(
      badgeNo: badgeNo ?? this.badgeNo,
      employeeName: employeeName ?? this.employeeName,
      businessLine: businessLine ?? this.businessLine,
      department: department ?? this.department,
      grade: grade ?? this.grade,
      status: status ?? this.status,
      position: position ?? this.position,
      basic: basic ?? this.basic,
      gradeRange: gradeRange ?? this.gradeRange,
      lastPromotionDate: lastPromotionDate ?? this.lastPromotionDate,
      uploadDate: uploadDate ?? this.uploadDate,
      id: id ?? this.id,
    );
  }
}
