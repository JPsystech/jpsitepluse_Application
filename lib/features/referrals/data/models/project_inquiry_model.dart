import 'package:equatable/equatable.dart';

class ProjectInquiryModel extends Equatable {
  final String id;
  final String referredByEngineerId;
  final String? referredByEngineerName;
  final String? referredByEmpCode;
  final String clientName;
  final String? contactPerson;
  final String? contactMobile;
  final String? contactEmail;
  final String? siteName;
  final String? siteAddress;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final double? estimatedValue;
  final double? expectedBonusAmount;
  final String? remarks;
  final String status;
  final String? convertedProjectId;
  final String? adminRemarks;
  final String? createdAt;
  final String? updatedAt;

  const ProjectInquiryModel({
    required this.id,
    required this.referredByEngineerId,
    this.referredByEngineerName,
    this.referredByEmpCode,
    required this.clientName,
    this.contactPerson,
    this.contactMobile,
    this.contactEmail,
    this.siteName,
    this.siteAddress,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.estimatedValue,
    this.expectedBonusAmount,
    this.remarks,
    required this.status,
    this.convertedProjectId,
    this.adminRemarks,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectInquiryModel.fromJson(Map<String, dynamic> json) {
    return ProjectInquiryModel(
      id: json['id']?.toString() ?? '',
      referredByEngineerId: json['referred_by_engineer_id']?.toString() ?? '',
      referredByEngineerName: json['referred_by_engineer_name']?.toString(),
      referredByEmpCode: json['referred_by_emp_code']?.toString(),
      clientName: json['client_name']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString(),
      contactMobile: json['contact_mobile']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      siteName: json['site_name']?.toString(),
      siteAddress: json['site_address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      estimatedValue: json['estimated_value'] != null
          ? (json['estimated_value'] as num).toDouble()
          : null,
      expectedBonusAmount: json['expected_bonus_amount'] != null
          ? (json['expected_bonus_amount'] as num).toDouble()
          : null,
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString() ?? 'NEW',
      convertedProjectId: json['converted_project_id']?.toString(),
      adminRemarks: json['admin_remarks']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referred_by_engineer_id': referredByEngineerId,
      'referred_by_engineer_name': referredByEngineerName,
      'referred_by_emp_code': referredByEmpCode,
      'client_name': clientName,
      'contact_person': contactPerson,
      'contact_mobile': contactMobile,
      'contact_email': contactEmail,
      'site_name': siteName,
      'site_address': siteAddress,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'estimated_value': estimatedValue,
      'expected_bonus_amount': expectedBonusAmount,
      'remarks': remarks,
      'status': status,
      'converted_project_id': convertedProjectId,
      'admin_remarks': adminRemarks,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  int get statusStep {
    switch (status.toUpperCase()) {
      case 'NEW':
        return 0;
      case 'CONTACTED':
        return 1;
      case 'QUALIFIED':
        return 2;
      case 'CONVERTED':
        return 3;
      case 'REJECTED':
      case 'DUPLICATE':
        return -1;
      default:
        return 0;
    }
  }

  @override
  List<Object?> get props => [
        id,
        referredByEngineerId,
        referredByEngineerName,
        referredByEmpCode,
        clientName,
        contactPerson,
        contactMobile,
        contactEmail,
        siteName,
        siteAddress,
        city,
        state,
        latitude,
        longitude,
        estimatedValue,
        expectedBonusAmount,
        remarks,
        status,
        convertedProjectId,
        adminRemarks,
        createdAt,
        updatedAt,
      ];
}
