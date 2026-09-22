import 'package:sitepulse_engineer/core/error/error_handler.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/candidate_referral_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/job_opening_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_reward_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_terms_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/services/referral_service.dart';

import '../models/project_inquiry_model.dart';

class ReferralRepository {
  final ReferralService service;

  ReferralRepository({ReferralService? service})
      : service = service ?? ReferralService();

  Future<List<JobOpeningModel>> getJobOpenings({
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await service.getJobOpenings(
        search: search,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<String> uploadResume({
    required List<int> bytes,
    required String originalFilename,
    required String contentType,
    required int sizeBytes,
    String? fileExtension,
  }) async {
    try {
      return await service.uploadResumeBytes(
        bytes: bytes,
        originalFilename: originalFilename,
        contentType: contentType,
        sizeBytes: sizeBytes,
        fileExtension: fileExtension,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<CandidateReferralModel> submitCandidateReferral({
    required String jobOpeningId,
    required String candidateName,
    required String candidateMobile,
    String? candidateEmail,
    String? currentCompany,
    double? totalExperienceYears,
    String? resumeFileKey,
    String? notes,
  }) async {
    try {
      return await service.submitCandidateReferral(
        jobOpeningId: jobOpeningId,
        candidateName: candidateName,
        candidateMobile: candidateMobile,
        candidateEmail: candidateEmail,
        currentCompany: currentCompany,
        totalExperienceYears: totalExperienceYears,
        resumeFileKey: resumeFileKey,
        notes: notes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<CandidateReferralModel>> getCandidateReferrals({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await service.getCandidateReferrals(
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<ProjectInquiryModel> submitProjectInquiry({
    required String clientName,
    String? contactPerson,
    String? contactMobile,
    String? contactEmail,
    String? siteName,
    String? siteAddress,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    double? estimatedValue,
    String? remarks,
  }) async {
    try {
      return await service.submitProjectInquiry(
        clientName: clientName,
        contactPerson: contactPerson,
        contactMobile: contactMobile,
        contactEmail: contactEmail,
        siteName: siteName,
        siteAddress: siteAddress,
        city: city,
        state: state,
        latitude: latitude,
        longitude: longitude,
        estimatedValue: estimatedValue,
        remarks: remarks,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<ProjectInquiryModel>> getProjectInquiries({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await service.getProjectInquiries(
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<ReferralRewardModel>> getRewards({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await service.getRewards(
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<ReferralTermsModel> getReferralTerms() async {
    try {
      return await service.getReferralTerms();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
