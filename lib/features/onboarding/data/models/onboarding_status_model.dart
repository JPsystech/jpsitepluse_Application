class OnboardingStatusModel {
  final bool isProfileComplete;
  final String? department;
  final List<String> requiredDocuments;
  final List<String> uploadedDocuments;
  final List<String> approvedDocuments;
  final List<String> pendingReviewDocuments;
  final List<String> rejectedDocuments;
  final List<String> missingDocuments;
  final List<String> missingFields;
  final int completionPercentage;

  const OnboardingStatusModel({
    required this.isProfileComplete,
    this.department,
    required this.requiredDocuments,
    required this.uploadedDocuments,
    this.approvedDocuments = const [],
    this.pendingReviewDocuments = const [],
    this.rejectedDocuments = const [],
    required this.missingDocuments,
    required this.missingFields,
    required this.completionPercentage,
  });

  /// Required documents that have not been uploaded at all (excluding rejected ones).
  List<String> get notUploadedDocuments =>
      missingDocuments.where((d) => !rejectedDocuments.contains(d)).toList();

  /// Total remaining required documents (matching Admin's outstandingRequiredDocuments:
  /// anything not yet APPROVED).
  int get remainingRequiredForAdminApproval =>
      requiredDocuments.where((d) => !approvedDocuments.contains(d)).length;

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
      approvedDocuments: (json["approved_documents"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      pendingReviewDocuments:
          (json["pending_review_documents"] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      rejectedDocuments: (json["rejected_documents"] as List<dynamic>?)
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

  /// Required document rules:
  /// - Mechanical ("Mechanical Engineer", "MECH", etc.) -> 6 required documents (includes NDT)
  /// - All other engineers -> 5 base required documents (CV, Degree, PAN, Aadhaar, Bank Passbook)
  static Set<String> getRequiredTypesForDepartment(String? department) {
    final norm = (department ?? "").trim().toLowerCase();
    if (norm.contains("mech")) {
      return const {
        "cv",
        "degree",
        "ndt",
        "pan",
        "aadhaar",
        "bank_passbook",
      };
    }
    return const {
      "cv",
      "degree",
      "pan",
      "aadhaar",
      "bank_passbook",
    };
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
        return "Degree / Education";
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
        return "Signature Photo";
      case "appointment_letter":
        return "Signed Appointment Letter";
      default:
        return docType.replaceAll("_", " ");
    }
  }
}

