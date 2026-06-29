class Engineer {
  final String id;
  final String empCode;
  final String fullName;
  final String mobileNo;
  final String? email;

  Engineer({
    required this.id,
    required this.empCode,
    required this.fullName,
    required this.mobileNo,
    required this.email,
  });

  factory Engineer.fromJson(Map<String, dynamic> json) {
    return Engineer(
      id: (json["id"] as String?) ?? "",
      empCode: (json["emp_code"] as String?) ?? "",
      fullName: (json["full_name"] as String?) ?? "",
      mobileNo: (json["mobile_no"] as String?) ?? "",
      email: json["email"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "emp_code": empCode,
      "full_name": fullName,
      "mobile_no": mobileNo,
      "email": email,
    };
  }
}
