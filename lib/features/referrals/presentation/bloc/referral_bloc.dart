import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/core/error/app_exception.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_terms_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/repositories/referral_repository.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_event.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_state.dart';

class ReferralBloc extends Bloc<ReferralEvent, ReferralState> {
  final ReferralRepository repository;

  ReferralBloc({ReferralRepository? repository})
      : repository = repository ?? ReferralRepository(),
        super(ReferralInitial()) {
    on<LoadReferralDataRequested>(_onLoadReferralData);
    on<SearchJobOpeningsRequested>(_onSearchJobOpenings);
    on<SubmitCandidateReferralRequested>(_onSubmitCandidateReferral);
    on<SubmitProjectInquiryRequested>(_onSubmitProjectInquiry);
  }

  Future<void> _onLoadReferralData(
    LoadReferralDataRequested event,
    Emitter<ReferralState> emit,
  ) async {
    if (!event.silent && state is! ReferralLoaded) {
      emit(ReferralLoading());
    }

    try {
      final results = await Future.wait([
        repository.getJobOpenings(),
        repository.getCandidateReferrals(),
        repository.getProjectInquiries(),
        repository.getRewards(),
        repository.getReferralTerms().catchError((_) => const ReferralTermsModel(
              candidateTermsTitle: 'Candidate Referral Program Terms & Conditions',
              candidateTermsContent: '',
              projectLeadTermsTitle: 'Project Lead Referral Terms & Conditions',
              projectLeadTermsContent: '',
            )),
      ]);

      final openings = results[0] as List;
      final candidates = results[1] as List;
      final inquiries = results[2] as List;
      final rewards = results[3] as List;
      final terms = results[4] as ReferralTermsModel;

      emit(ReferralLoaded(
        jobOpenings: openings.cast(),
        candidateReferrals: candidates.cast(),
        projectInquiries: inquiries.cast(),
        rewards: rewards.cast(),
        referralTerms: terms,
      ));
    } catch (e) {
      if (state is ReferralLoaded) {
        // Keep existing loaded data if silent refresh failed
        return;
      }
      final message = e is AppException ? e.userMessage : e.toString();
      emit(ReferralError(message));
    } finally {
      if (event.completer != null && !event.completer!.isCompleted) {
        event.completer!.complete();
      }
    }
  }

  Future<void> _onSearchJobOpenings(
    SearchJobOpeningsRequested event,
    Emitter<ReferralState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ReferralLoaded) return;

    try {
      final openings = await repository.getJobOpenings(search: event.query);
      emit(currentState.copyWith(
        jobOpenings: openings,
        searchQuery: event.query,
      ));
    } catch (e) {
      final message = e is AppException ? e.userMessage : e.toString();
      emit(currentState.copyWith(submitErrorMessage: message));
    }
  }

  Future<void> _onSubmitCandidateReferral(
    SubmitCandidateReferralRequested event,
    Emitter<ReferralState> emit,
  ) async {
    final currentState = state;
    if (currentState is ReferralLoaded) {
      emit(currentState.copyWith(isSubmitting: true, clearSubmitStatus: true));
    }

    try {
      String? resumeKey;
      if (event.resumeFile != null && await event.resumeFile!.exists()) {
        final file = event.resumeFile!;
        final bytes = await file.readAsBytes();
        final path = file.path;
        final separator = Platform.isWindows ? '\\' : '/';
        final fileName = path.contains(separator)
            ? path.split(separator).last
            : path.split('/').last;
        final ext = fileName.contains('.') ? '.${fileName.split('.').last.toLowerCase()}' : '';

        String contentType = 'application/pdf';
        if (ext == '.doc') {
          contentType = 'application/msword';
        } else if (ext == '.docx') {
          contentType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        }

        resumeKey = await repository.uploadResume(
          bytes: bytes,
          originalFilename: fileName,
          contentType: contentType,
          sizeBytes: bytes.length,
          fileExtension: ext,
        );
      }

      await repository.submitCandidateReferral(
        jobOpeningId: event.jobOpeningId,
        candidateName: event.candidateName,
        candidateMobile: event.candidateMobile,
        candidateEmail: event.candidateEmail,
        currentCompany: event.currentCompany,
        totalExperienceYears: event.totalExperienceYears,
        resumeFileKey: resumeKey,
        notes: event.notes,
      );

      // Refresh data
      final results = await Future.wait([
        repository.getJobOpenings(),
        repository.getCandidateReferrals(),
        repository.getProjectInquiries(),
        repository.getRewards(),
      ]);

      emit(ReferralLoaded(
        jobOpenings: results[0].cast(),
        candidateReferrals: results[1].cast(),
        projectInquiries: results[2].cast(),
        rewards: results[3].cast(),
        referralTerms:
            currentState is ReferralLoaded ? currentState.referralTerms : null,
        submitSuccessMessage: 'Candidate referral submitted successfully!',
      ));
    } catch (e) {
      final message = e is AppException ? e.userMessage : e.toString();
      if (state is ReferralLoaded) {
        emit((state as ReferralLoaded).copyWith(
          isSubmitting: false,
          submitErrorMessage: message,
        ));
      } else {
        emit(ReferralError(message));
      }
    }
  }

  Future<void> _onSubmitProjectInquiry(
    SubmitProjectInquiryRequested event,
    Emitter<ReferralState> emit,
  ) async {
    final currentState = state;
    if (currentState is ReferralLoaded) {
      emit(currentState.copyWith(isSubmitting: true, clearSubmitStatus: true));
    }

    try {
      await repository.submitProjectInquiry(
        clientName: event.clientName,
        contactPerson: event.contactPerson,
        contactMobile: event.contactMobile,
        contactEmail: event.contactEmail,
        siteName: event.siteName,
        siteAddress: event.siteAddress,
        city: event.city,
        state: event.state,
        latitude: event.latitude,
        longitude: event.longitude,
        estimatedValue: event.estimatedValue,
        remarks: event.remarks,
      );

      // Refresh data
      final results = await Future.wait([
        repository.getJobOpenings(),
        repository.getCandidateReferrals(),
        repository.getProjectInquiries(),
        repository.getRewards(),
      ]);

      emit(ReferralLoaded(
        jobOpenings: results[0].cast(),
        candidateReferrals: results[1].cast(),
        projectInquiries: results[2].cast(),
        rewards: results[3].cast(),
        referralTerms: currentState is ReferralLoaded ? currentState.referralTerms : null,
        submitSuccessMessage: 'Project lead submitted successfully!',
      ));
    } catch (e) {
      final message = e is AppException ? e.userMessage : e.toString();
      if (state is ReferralLoaded) {
        emit((state as ReferralLoaded).copyWith(
          isSubmitting: false,
          submitErrorMessage: message,
        ));
      } else {
        emit(ReferralError(message));
      }
    }
  }
}
