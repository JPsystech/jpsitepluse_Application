import 'package:equatable/equatable.dart';

class CandidateReferralModel extends Equatable {
  final String id;
  final String jobOpeningId;
  final String? jobTitle;
  final String? jobDepartment;
  final String? jobDesignation;
  final String? jobLocation;
  final String referredByEngineerId;
  final String? referredByEngineerName;
  final String? referredByEmpCode;
  final String candidateName;
  final String candidateMobile;
  final String? candidateEmail;
  final String? currentCompany;
  final double? totalExperienceYears;
  final String? resumeFileKey;
  final String? resumeDownloadUrl;
  final String? notes;
  final String currentStage;
  final String? adminRemarks;
  final String? selectedAt;
  final String? joinedAt;
  final String? createdAt;
  final String? updatedAt;

  const CandidateReferralModel({
    required this.id,
    required this.jobOpeningId,
    this.jobTitle,
    this.jobDepartment,
    this.jobDesignation,
    this.jobLocation,
    required this.referredByEngineerId,
    this.referredByEngineerName,
    this.referredByEmpCode,
    required this.candidateName,
    required this.candidateMobile,
    this.candidateEmail,
    this.currentCompany,
    this.totalExperienceYears,
    this.resumeFileKey,
    this.resumeDownloadUrl,
    this.notes,
    required this.currentStage,
    this.adminRemarks,
    this.selectedAt,
    this.joinedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory CandidateReferralModel.fromJson(Map<String, dynamic> json) {
    return CandidateReferralModel(
      id: json['id']?.toString() ?? '',
      jobOpeningId: json['job_opening_id']?.toString() ?? '',
      jobTitle: json['job_title']?.toString(),
      jobDepartment: json['job_department']?.toString(),
      jobDesignation: json['job_designation']?.toString(),
      jobLocation: json['job_location']?.toString(),
      referredByEngineerId: json['referred_by_engineer_id']?.toString() ?? '',
      referredByEngineerName: json['referred_by_engineer_name']?.toString(),
      referredByEmpCode: json['referred_by_emp_code']?.toString(),
      candidateName: json['candidate_name']?.toString() ?? '',
      candidateMobile: json['candidate_mobile']?.toString() ?? '',
      candidateEmail: json['candidate_email']?.toString(),
      currentCompany: json['current_company']?.toString(),
      totalExperienceYears: json['total_experience_years'] != null
          ? (json['total_experience_years'] as num).toDouble()
          : null,
      resumeFileKey: json['resume_file_key']?.toString(),
      resumeDownloadUrl: json['resume_download_url']?.toString(),
      notes: json['notes']?.toString(),
      currentStage: json['current_stage']?.toString() ?? 'SUBMITTED',
      adminRemarks: json['admin_remarks']?.toString(),
      selectedAt: json['selected_at']?.toString(),
      joinedAt: json['joined_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_opening_id': jobOpeningId,
      'job_title': jobTitle,
      'job_department': jobDepartment,
      'job_designation': jobDesignation,
      'job_location': jobLocation,
      'referred_by_engineer_id': referredByEngineerId,
      'referred_by_engineer_name': referredByEngineerName,
      'referred_by_emp_code': referredByEmpCode,
      'candidate_name': candidateName,
      'candidate_mobile': candidateMobile,
      'candidate_email': candidateEmail,
      'current_company': currentCompany,
      'total_experience_years': totalExperienceYears,
      'resume_file_key': resumeFileKey,
      'resume_download_url': resumeDownloadUrl,
      'notes': notes,
      'current_stage': currentStage,
      'admin_remarks': adminRemarks,
      'selected_at': selectedAt,
      'joined_at': joinedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  int get stageStep {
    switch (currentStage.toUpperCase()) {
      case 'SUBMITTED':
        return 0;
      case 'SCREENING':
        return 1;
      case 'INTERVIEW':
        return 2;
      case 'SELECTED':
        return 3;
      case 'JOINED':
        return 4;
      case 'REJECTED':
        return -1;
      default:
        return 0;
    }
  }

  @override
  List<Object?> get props => [
        id,
        jobOpeningId,
        jobTitle,
        jobDepartment,
        jobDesignation,
        jobLocation,
        referredByEngineerId,
        referredByEngineerName,
        referredByEmpCode,
        candidateName,
        candidateMobile,
        candidateEmail,
        currentCompany,
        totalExperienceYears,
        resumeFileKey,
        resumeDownloadUrl,
        notes,
        currentStage,
        adminRemarks,
        selectedAt,
        joinedAt,
        createdAt,
        updatedAt,
      ];
}
