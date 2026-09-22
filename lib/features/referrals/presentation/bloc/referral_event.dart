import 'dart:async';
import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class ReferralEvent extends Equatable {
  const ReferralEvent();

  @override
  List<Object?> get props => [];
}

class LoadReferralDataRequested extends ReferralEvent {
  final bool silent;
  final Completer<void>? completer;

  const LoadReferralDataRequested({this.silent = false, this.completer});

  @override
  List<Object?> get props => [silent];
}

class SearchJobOpeningsRequested extends ReferralEvent {
  final String query;

  const SearchJobOpeningsRequested(this.query);

  @override
  List<Object?> get props => [query];
}

class SubmitCandidateReferralRequested extends ReferralEvent {
  final String jobOpeningId;
  final String candidateName;
  final String candidateMobile;
  final String? candidateEmail;
  final String? currentCompany;
  final double? totalExperienceYears;
  final File? resumeFile;
  final String? notes;

  const SubmitCandidateReferralRequested({
    required this.jobOpeningId,
    required this.candidateName,
    required this.candidateMobile,
    this.candidateEmail,
    this.currentCompany,
    this.totalExperienceYears,
    this.resumeFile,
    this.notes,
  });

  @override
  List<Object?> get props => [
        jobOpeningId,
        candidateName,
        candidateMobile,
        candidateEmail,
        currentCompany,
        totalExperienceYears,
        resumeFile?.path,
        notes,
      ];
}

class SubmitProjectInquiryRequested extends ReferralEvent {
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
  final String? remarks;

  const SubmitProjectInquiryRequested({
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
    this.remarks,
  });

  @override
  List<Object?> get props => [
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
        remarks,
      ];
}
