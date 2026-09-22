import 'package:equatable/equatable.dart';

class ReferralTermsModel extends Equatable {
  final String candidateTermsTitle;
  final String candidateTermsContent;
  final String projectLeadTermsTitle;
  final String projectLeadTermsContent;
  final DateTime? updatedAt;

  const ReferralTermsModel({
    required this.candidateTermsTitle,
    required this.candidateTermsContent,
    required this.projectLeadTermsTitle,
    required this.projectLeadTermsContent,
    this.updatedAt,
  });

  factory ReferralTermsModel.fromJson(Map<String, dynamic> json) {
    return ReferralTermsModel(
      candidateTermsTitle: json['candidate_terms_title'] as String? ??
          'Candidate Referral Program Terms & Conditions',
      candidateTermsContent: json['candidate_terms_content'] as String? ?? '',
      projectLeadTermsTitle: json['project_lead_terms_title'] as String? ??
          'Project Lead Referral Terms & Conditions',
      projectLeadTermsContent: json['project_lead_terms_content'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'candidate_terms_title': candidateTermsTitle,
      'candidate_terms_content': candidateTermsContent,
      'project_lead_terms_title': projectLeadTermsTitle,
      'project_lead_terms_content': projectLeadTermsContent,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        candidateTermsTitle,
        candidateTermsContent,
        projectLeadTermsTitle,
        projectLeadTermsContent,
        updatedAt,
      ];
}
