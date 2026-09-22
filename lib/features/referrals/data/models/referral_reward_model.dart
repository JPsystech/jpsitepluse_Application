import 'package:equatable/equatable.dart';

class ReferralRewardModel extends Equatable {
  final String id;
  final String engineerId;
  final String? engineerName;
  final String? engineerEmpCode;
  final String sourceType;
  final String sourceId;
  final String sourceLabel;
  final String? sourceTitle;
  final String? sourceDescription;
  final double amount;
  final String currency;
  final String status;
  final String? approvedAt;
  final String? paidAt;
  final String? paymentReference;
  final String? remarks;
  final String? createdAt;
  final String? updatedAt;

  const ReferralRewardModel({
    required this.id,
    required this.engineerId,
    this.engineerName,
    this.engineerEmpCode,
    required this.sourceType,
    required this.sourceId,
    required this.sourceLabel,
    this.sourceTitle,
    this.sourceDescription,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.approvedAt,
    this.paidAt,
    this.paymentReference,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  factory ReferralRewardModel.fromJson(Map<String, dynamic> json) {
    return ReferralRewardModel(
      id: json['id']?.toString() ?? '',
      engineerId: json['engineer_id']?.toString() ?? '',
      engineerName: json['engineer_name']?.toString(),
      engineerEmpCode: json['engineer_emp_code']?.toString(),
      sourceType: json['source_type']?.toString() ?? 'HIRING_REFERRAL',
      sourceId: json['source_id']?.toString() ?? '',
      sourceLabel: json['source_label']?.toString() ?? 'Referral',
      sourceTitle: json['source_title']?.toString(),
      sourceDescription: json['source_description']?.toString(),
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString() ?? 'PENDING',
      approvedAt: json['approved_at']?.toString(),
      paidAt: json['paid_at']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      remarks: json['remarks']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'engineer_id': engineerId,
      'engineer_name': engineerName,
      'engineer_emp_code': engineerEmpCode,
      'source_type': sourceType,
      'source_id': sourceId,
      'source_label': sourceLabel,
      'source_title': sourceTitle,
      'source_description': sourceDescription,
      'amount': amount,
      'currency': currency,
      'status': status,
      'approved_at': approvedAt,
      'paid_at': paidAt,
      'payment_reference': paymentReference,
      'remarks': remarks,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isPayable => status.toUpperCase() == 'PAYABLE' || status.toUpperCase() == 'APPROVED';
  bool get isPending => status.toUpperCase() == 'PENDING';

  @override
  List<Object?> get props => [
        id,
        engineerId,
        engineerName,
        engineerEmpCode,
        sourceType,
        sourceId,
        sourceLabel,
        sourceTitle,
        sourceDescription,
        amount,
        currency,
        status,
        approvedAt,
        paidAt,
        paymentReference,
        remarks,
        createdAt,
        updatedAt,
      ];
}
