import 'package:equatable/equatable.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/candidate_referral_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/job_opening_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/project_inquiry_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_reward_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_terms_model.dart';

abstract class ReferralState extends Equatable {
  const ReferralState();

  @override
  List<Object?> get props => [];
}

class ReferralInitial extends ReferralState {}

class ReferralLoading extends ReferralState {}

class ReferralLoaded extends ReferralState {
  final List<JobOpeningModel> jobOpenings;
  final List<CandidateReferralModel> candidateReferrals;
  final List<ProjectInquiryModel> projectInquiries;
  final List<ReferralRewardModel> rewards;
  final ReferralTermsModel? referralTerms;
  final String? searchQuery;
  final bool isSubmitting;
  final String? submitSuccessMessage;
  final String? submitErrorMessage;

  const ReferralLoaded({
    required this.jobOpenings,
    required this.candidateReferrals,
    required this.projectInquiries,
    required this.rewards,
    this.referralTerms,
    this.searchQuery,
    this.isSubmitting = false,
    this.submitSuccessMessage,
    this.submitErrorMessage,
  });

  ReferralLoaded copyWith({
    List<JobOpeningModel>? jobOpenings,
    List<CandidateReferralModel>? candidateReferrals,
    List<ProjectInquiryModel>? projectInquiries,
    List<ReferralRewardModel>? rewards,
    ReferralTermsModel? referralTerms,
    String? searchQuery,
    bool? isSubmitting,
    String? submitSuccessMessage,
    String? submitErrorMessage,
    bool clearSubmitStatus = false,
  }) {
    return ReferralLoaded(
      jobOpenings: jobOpenings ?? this.jobOpenings,
      candidateReferrals: candidateReferrals ?? this.candidateReferrals,
      projectInquiries: projectInquiries ?? this.projectInquiries,
      rewards: rewards ?? this.rewards,
      referralTerms: referralTerms ?? this.referralTerms,
      searchQuery: searchQuery ?? this.searchQuery,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccessMessage:
          clearSubmitStatus ? null : (submitSuccessMessage ?? this.submitSuccessMessage),
      submitErrorMessage:
          clearSubmitStatus ? null : (submitErrorMessage ?? this.submitErrorMessage),
    );
  }

  double get totalPaidAmount {
    return rewards
        .where((r) => r.isPaid)
        .fold<double>(0.0, (sum, r) => sum + r.amount);
  }

  double get totalPayableAmount {
    return rewards
        .where((r) => r.isPayable)
        .fold<double>(0.0, (sum, r) => sum + r.amount);
  }

  double get totalPendingAmount {
    return rewards
        .where((r) => r.isPending)
        .fold<double>(0.0, (sum, r) => sum + r.amount);
  }

  int get activeCandidatesCount {
    return candidateReferrals
        .where((c) =>
            c.currentStage.toUpperCase() != 'JOINED' &&
            c.currentStage.toUpperCase() != 'REJECTED')
        .length;
  }

  int get activeProjectInquiriesCount {
    return projectInquiries
        .where((p) =>
            p.status.toUpperCase() != 'CONVERTED' &&
            p.status.toUpperCase() != 'REJECTED' &&
            p.status.toUpperCase() != 'DUPLICATE')
        .length;
  }

  @override
  List<Object?> get props => [
        jobOpenings,
        candidateReferrals,
        projectInquiries,
        rewards,
        referralTerms,
        searchQuery,
        isSubmitting,
        submitSuccessMessage,
        submitErrorMessage,
      ];
}

class ReferralError extends ReferralState {
  final String message;

  const ReferralError(this.message);

  @override
  List<Object?> get props => [message];
}
