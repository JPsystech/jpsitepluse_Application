import 'dart:io';
import 'package:dio/dio.dart';
import 'package:sitepulse_engineer/core/error/app_exception.dart';
import 'package:sitepulse_engineer/core/error/error_type.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/candidate_referral_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/candidate_resume_presign_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/job_opening_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/project_inquiry_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_reward_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_terms_model.dart';

class ReferralService {
  final ApiClient api;

  ReferralService({ApiClient? api}) : api = api ?? ApiClient.instance;

  Future<List<JobOpeningModel>> getJobOpenings({
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    final client = await api.dio;
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final res = await client.get(
      '/api/v1/referrals/engineer/job-openings',
      queryParameters: queryParams,
    );

    final data = res.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((item) => JobOpeningModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<CandidateResumePresignModel> presignResume({
    required String originalFilename,
    required String contentType,
    required int sizeBytes,
    String? fileExtension,
  }) async {
    final client = await api.dio;
    final res = await client.post(
      '/api/v1/referrals/engineer/candidate-referrals/presign',
      data: {
        'original_filename': originalFilename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        if (fileExtension != null && fileExtension.isNotEmpty)
          'file_extension': fileExtension,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return CandidateResumePresignModel.fromJson(data);
    }
    throw const AppException(
      userMessage: 'Failed to get presigned upload URL for resume',
      type: AppErrorType.unknown,
    );
  }

  Future<String> uploadResumeBytes({
    required List<int> bytes,
    required String originalFilename,
    required String contentType,
    required int sizeBytes,
    String? fileExtension,
  }) async {
    final presigned = await presignResume(
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      fileExtension: fileExtension,
    );

    var uploadUrl = presigned.uploadUrl.trim();
    if (!uploadUrl.startsWith('http')) {
      final base = (await api.dio).options.baseUrl;
      uploadUrl = '$base$uploadUrl';
    }

    final headers = <String, dynamic>{
      HttpHeaders.contentTypeHeader: contentType,
      ...presigned.requiredHeaders,
    };

    final uploadDio = Dio();
    final res = await uploadDio.put(
      uploadUrl,
      data: bytes,
      options: Options(headers: headers),
    );

    if (res.statusCode != 200 && res.statusCode != 201 && res.statusCode != 204) {
      throw const AppException(
        userMessage: 'Resume upload failed',
        type: AppErrorType.network,
      );
    }

    return presigned.key;
  }

  Future<Map<String, dynamic>> checkCandidateDuplicate({
    required String mobile,
    String? jobOpeningId,
    String? email,
  }) async {
    final client = await api.dio;
    try {
      final res = await client.get(
        '/api/v1/referrals/engineer/check-candidate-duplicate',
        queryParameters: {
          'mobile': mobile.trim(),
          if (jobOpeningId != null && jobOpeningId.trim().isNotEmpty)
            'job_opening_id': jobOpeningId.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return {'is_duplicate': false};
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
    final client = await api.dio;
    try {
      final res = await client.post(
        '/api/v1/referrals/engineer/candidate-referrals',
        data: {
          'job_opening_id': jobOpeningId,
          'candidate_name': candidateName.trim(),
          'candidate_mobile': candidateMobile.trim(),
          if (candidateEmail != null && candidateEmail.trim().isNotEmpty)
            'candidate_email': candidateEmail.trim(),
          if (currentCompany != null && currentCompany.trim().isNotEmpty)
            'current_company': currentCompany.trim(),
          if (totalExperienceYears != null)
            'total_experience_years': totalExperienceYears,
          if (resumeFileKey != null && resumeFileKey.trim().isNotEmpty)
            'resume_file_key': resumeFileKey.trim(),
          if (notes != null && notes.trim().isNotEmpty)
            'notes': notes.trim(),
        },
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        return CandidateReferralModel.fromJson(data);
      }
      throw const AppException(
        userMessage: 'Failed to submit candidate referral',
        type: AppErrorType.unknown,
      );
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        final detail = data['detail'] ?? data['message'] ?? data['error']?['message'];
        if (detail != null) {
          throw AppException(
            userMessage: detail.toString(),
            statusCode: e.response?.statusCode,
            type: e.response?.statusCode == 409
                ? AppErrorType.validation
                : AppErrorType.server,
          );
        }
      }
      throw AppException(
        userMessage: e.message ?? 'Submission failed. Please check network connection.',
        statusCode: e.response?.statusCode,
        type: AppErrorType.network,
      );
    }
  }

  Future<List<CandidateReferralModel>> getCandidateReferrals({
    int limit = 100,
    int offset = 0,
  }) async {
    final client = await api.dio;
    final res = await client.get(
      '/api/v1/referrals/engineer/candidate-referrals',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((item) =>
              CandidateReferralModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
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
    final client = await api.dio;
    try {
      final res = await client.post(
        '/api/v1/referrals/engineer/project-inquiries',
        data: {
          'client_name': clientName.trim(),
          if (contactPerson != null && contactPerson.trim().isNotEmpty)
            'contact_person': contactPerson.trim(),
          if (contactMobile != null && contactMobile.trim().isNotEmpty)
            'contact_mobile': contactMobile.trim(),
          if (contactEmail != null && contactEmail.trim().isNotEmpty)
            'contact_email': contactEmail.trim(),
          if (siteName != null && siteName.trim().isNotEmpty)
            'site_name': siteName.trim(),
          if (siteAddress != null && siteAddress.trim().isNotEmpty)
            'site_address': siteAddress.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
          if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (estimatedValue != null) 'estimated_value': estimatedValue,
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
        },
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        return ProjectInquiryModel.fromJson(data);
      }
      throw const AppException(
        userMessage: 'Failed to submit project inquiry',
        type: AppErrorType.unknown,
      );
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        final detail = data['detail'] ?? data['message'] ?? data['error']?['message'];
        if (detail != null) {
          throw AppException(
            userMessage: detail.toString(),
            statusCode: e.response?.statusCode,
            type: e.response?.statusCode == 409
                ? AppErrorType.validation
                : AppErrorType.server,
          );
        }
      }
      throw AppException(
        userMessage: e.message ?? 'Submission failed. Please check network connection.',
        statusCode: e.response?.statusCode,
        type: AppErrorType.network,
      );
    }
  }


  Future<List<ProjectInquiryModel>> getProjectInquiries({
    int limit = 100,
    int offset = 0,
  }) async {
    final client = await api.dio;
    final res = await client.get(
      '/api/v1/referrals/engineer/project-inquiries',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((item) =>
              ProjectInquiryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<ReferralRewardModel>> getRewards({
    int limit = 100,
    int offset = 0,
  }) async {
    final client = await api.dio;
    final res = await client.get(
      '/api/v1/referrals/engineer/rewards',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((item) =>
              ReferralRewardModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ReferralTermsModel> getReferralTerms() async {
    final client = await api.dio;
    final res = await client.get('/api/v1/referrals/terms');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return ReferralTermsModel.fromJson(data);
    }
    throw const AppException(
      userMessage: 'Failed to fetch referral terms',
      type: AppErrorType.server,
    );
  }
}
