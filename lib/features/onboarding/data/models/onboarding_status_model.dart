class OnboardingStatusModel {
  final bool isProfileComplete;
  final String? department;
  final List<String> requiredDocuments;
  final List<String> uploadedDocuments;
  final List<String> missingDocuments;
  final List<String> missingFields;
  final int completionPercentage;

  const OnboardingStatusModel({
    required this.isProfileComplete,
    this.department,
    required this.requiredDocuments,
    required this.uploadedDocuments,
    required this.missingDocuments,
    required this.missingFields,
    required this.completionPercentage,
  });

  factory OnboardingStatusModel.fromJson(Map<String, dynamic> json) {
    return OnboardingStatusModel(
      isProfileComplete: (json["is_profile_complete"] as bool?) ?? false,
      department: json["department"] as String?,
      requiredDocuments: (json["required_documents"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      uploadedDocuments: (json["uploaded_documents"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      missingDocuments: (json["missing_documents"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      missingFields: (json["missing_fields"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      completionPercentage:
          (json["completion_percentage"] as num?)?.toInt() ?? 0,
    );
  }

  static String fieldDisplayName(String field) {
    switch (field) {
      case "birth_date":
        return "Date of Birth";
      case "pan_card_number":
        return "PAN Card Number";
      case "aadhaar_card_number":
        return "Aadhaar Card Number";
      case "bank_account_holder_name":
        return "Account Holder Name";
      case "bank_name":
        return "Bank Name";
      case "bank_account_number":
        return "Bank Account Number";
      case "bank_ifsc_code":
        return "Bank IFSC Code";
      default:
        return field;
    }
  }

  static String docDisplayName(String docType) {
    switch (docType) {
      case "cv":
        return "CV / Resume";
      case "degree":
        return "Degree / Diploma Certificate";
      case "ndt":
        return "NDT Certificate";
      case "pan":
        return "PAN Card";
      case "aadhaar":
        return "Aadhaar Card";
      case "bank_passbook":
        return "Bank Passbook / Cancelled Cheque";
      case "selfie":
        return "Selfie / Passport Photo";
      case "signature":
        return "Signature";
      case "appointment_letter":
        return "Appointment Letter";
      default:
        return docType.replaceAll("_", " ");
    }
  }
}
