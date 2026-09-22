import 'package:equatable/equatable.dart';

class JobOpeningModel extends Equatable {
  final String id;
  final String title;
  final String? department;
  final String? designation;
  final String? location;
  final double? experienceMinYears;
  final double? experienceMaxYears;
  final String? description;
  final double? bonusAmount;
  final String status;
  final String? publishedAt;
  final String? createdAt;
  final String? updatedAt;

  const JobOpeningModel({
    required this.id,
    required this.title,
    this.department,
    this.designation,
    this.location,
    this.experienceMinYears,
    this.experienceMaxYears,
    this.description,
    this.bonusAmount,
    required this.status,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory JobOpeningModel.fromJson(Map<String, dynamic> json) {
    return JobOpeningModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      department: json['department']?.toString(),
      designation: json['designation']?.toString(),
      location: json['location']?.toString(),
      experienceMinYears: json['experience_min_years'] != null
          ? (json['experience_min_years'] as num).toDouble()
          : null,
      experienceMaxYears: json['experience_max_years'] != null
          ? (json['experience_max_years'] as num).toDouble()
          : null,
      description: json['description']?.toString(),
      bonusAmount: json['bonus_amount'] != null
          ? (json['bonus_amount'] as num).toDouble()
          : null,
      status: json['status']?.toString() ?? 'OPEN',
      publishedAt: json['published_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'department': department,
      'designation': designation,
      'location': location,
      'experience_min_years': experienceMinYears,
      'experience_max_years': experienceMaxYears,
      'description': description,
      'bonus_amount': bonusAmount,
      'status': status,
      'published_at': publishedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get experienceRange {
    if (experienceMinYears != null && experienceMaxYears != null) {
      return '${experienceMinYears!.toStringAsFixed(experienceMinYears! % 1 == 0 ? 0 : 1)} - ${experienceMaxYears!.toStringAsFixed(experienceMaxYears! % 1 == 0 ? 0 : 1)} Yrs';
    } else if (experienceMinYears != null) {
      return '${experienceMinYears!.toStringAsFixed(experienceMinYears! % 1 == 0 ? 0 : 1)}+ Yrs';
    } else if (experienceMaxYears != null) {
      return 'Up to ${experienceMaxYears!.toStringAsFixed(experienceMaxYears! % 1 == 0 ? 0 : 1)} Yrs';
    }
    return 'Experience not specified';
  }

  bool get isOpen => status.toUpperCase() == 'OPEN';
  bool get isOnHold => status.toUpperCase() == 'ON_HOLD';
  bool get isClosed => status.toUpperCase() == 'CLOSED';

  @override
  List<Object?> get props => [
        id,
        title,
        department,
        designation,
        location,
        experienceMinYears,
        experienceMaxYears,
        description,
        bonusAmount,
        status,
        publishedAt,
        createdAt,
        updatedAt,
      ];
}
