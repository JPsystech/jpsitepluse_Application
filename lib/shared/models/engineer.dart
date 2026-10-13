class Engineer {
  final String id;
  final String empCode;
  final String fullName;
  final String mobileNo;
  final String? email;
  final String? designation;
  final String? department;
  final List<int> weeklyOffDays;
  final String? birthDate;
  final String? bankAccountHolderName;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? uanNumber;
  final String? panCardNumber;
  final String? aadhaarCardNumber;
  final double? salary;

  Engineer({
    required this.id,
    required this.empCode,
    required this.fullName,
    required this.mobileNo,
    required this.email,
    this.designation,
    this.department,
    this.weeklyOffDays = const [6],
    this.birthDate,
    this.bankAccountHolderName,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.uanNumber,
    this.panCardNumber,
    this.aadhaarCardNumber,
    this.salary,
  });

  /// Checks if a given date is a weekly off day for this engineer.
  /// Note: Dart's [DateTime.weekday] is 1 (Mon) to 7 (Sun), while Python backend is 0 (Mon) to 6 (Sun).
  bool isWeeklyOff(DateTime date) {
    final pyWeekday = date.weekday - 1;
    return weeklyOffDays.contains(pyWeekday);
  }

  /// Returns a comma-separated string of the engineer's weekly off days (e.g. "Sun" or "Sat, Sun").
  String get weeklyOffDaysDisplay {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weeklyOffDays.isEmpty) return 'None';
    final sorted = List<int>.from(weeklyOffDays)..sort();
    return sorted
        .map((d) => (d >= 0 && d < 7) ? names[d] : '')
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  factory Engineer.fromJson(Map<String, dynamic> json) {
    List<int> parsedWeeklyOff = const [6];
    final rawWeeklyOff = json["weekly_off_days"];
    if (rawWeeklyOff is List) {
      parsedWeeklyOff = rawWeeklyOff
          .map((e) => (e as num?)?.toInt())
          .whereType<int>()
          .toList();
      if (parsedWeeklyOff.isEmpty) parsedWeeklyOff = const [6];
    } else if (rawWeeklyOff is String && rawWeeklyOff.trim().isNotEmpty) {
      parsedWeeklyOff = rawWeeklyOff
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      if (parsedWeeklyOff.isEmpty) parsedWeeklyOff = const [6];
    }

    return Engineer(
      id: (json["id"] as String?) ?? "",
      empCode: (json["emp_code"] as String?) ?? "",
      fullName: (json["full_name"] as String?) ?? "",
      mobileNo: (json["mobile_no"] as String?) ?? "",
      email: json["email"] as String?,
      designation: json["designation"] as String?,
      department: json["department"] as String?,
      weeklyOffDays: parsedWeeklyOff,
      birthDate: json["birth_date"]?.toString(),
      bankAccountHolderName: json["bank_account_holder_name"] as String?,
      bankName: json["bank_name"] as String?,
      bankAccountNumber: json["bank_account_number"] as String?,
      bankIfscCode: json["bank_ifsc_code"] as String?,
      uanNumber: json["uan_number"] as String?,
      panCardNumber: json["pan_card_number"] as String?,
      aadhaarCardNumber: json["aadhaar_card_number"] as String?,
      salary: (json["salary"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "emp_code": empCode,
      "full_name": fullName,
      "mobile_no": mobileNo,
      "email": email,
      "designation": designation,
      "department": department,
      "weekly_off_days": weeklyOffDays,
      "birth_date": birthDate,
      "bank_account_holder_name": bankAccountHolderName,
      "bank_name": bankName,
      "bank_account_number": bankAccountNumber,
      "bank_ifsc_code": bankIfscCode,
      "uan_number": uanNumber,
      "pan_card_number": panCardNumber,
      "aadhaar_card_number": aadhaarCardNumber,
      "salary": salary,
    };
  }
}
