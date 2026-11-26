import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/job_opening_model.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_event.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_state.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/referral_terms_sheet.dart';
import 'package:sitepulse_engineer/shared/models/country_code.dart';
import 'package:sitepulse_engineer/shared/widgets/country_code_phone_field.dart';
import 'package:sitepulse_engineer/shared/widgets/app_form_fields.dart';
import 'package:sitepulse_engineer/shared/widgets/app_file_upload_card.dart';

class ReferCandidateScreen extends StatelessWidget {
  final JobOpeningModel? preselectedJob;
  final ReferralBloc? bloc;

  const ReferCandidateScreen({
    super.key,
    this.preselectedJob,
    this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: _ReferCandidateScreenContent(preselectedJob: preselectedJob),
      );
    }

    try {
      final existing = context.read<ReferralBloc>();
      return BlocProvider.value(
        value: existing,
        child: _ReferCandidateScreenContent(preselectedJob: preselectedJob),
      );
    } catch (_) {
      return BlocProvider(
        create: (_) => ReferralBloc()..add(const LoadReferralDataRequested()),
        child: _ReferCandidateScreenContent(preselectedJob: preselectedJob),
      );
    }
  }
}

class _ReferCandidateScreenContent extends StatefulWidget {
  final JobOpeningModel? preselectedJob;

  const _ReferCandidateScreenContent({
    this.preselectedJob,
  });

  @override
  State<_ReferCandidateScreenContent> createState() =>
      _ReferCandidateScreenContentState();
}

class _ReferCandidateScreenContentState
    extends State<_ReferCandidateScreenContent> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedJobId;

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  CountryCode _selectedCountry = CountryCode.india;
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _expController = TextEditingController();
  final _notesController = TextEditingController();

  File? _selectedResumeFile;
  String? _resumeFileName;
  int? _resumeFileSize;

  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedJob != null) {
      _selectedJobId = widget.preselectedJob!.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _expController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final size = await file.length();

        if (size > 15 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Resume file size must be less than 15 MB"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final separator = Platform.isWindows ? '\\' : '/';
        final fileName = path.contains(separator)
            ? path.split(separator).last
            : path.split('/').last;

        setState(() {
          _selectedResumeFile = file;
          _resumeFileName = fileName;
          _resumeFileSize = size;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to select file: $e")),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedJobId == null || _selectedJobId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a job opening"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final candidateMobDigits = _mobileController.text.trim().replaceAll(RegExp(r'\D'), '');
    final fullCandidateMobile = "${_selectedCountry.dialCode} ${_mobileController.text.trim()}";
    final currentEngMob = SessionStore.current?.engineer.mobileNo.trim().replaceAll(RegExp(r'\D'), '');
    if (currentEngMob != null && currentEngMob.isNotEmpty) {
      final normCurrent = currentEngMob.length >= 10
          ? currentEngMob.substring(currentEngMob.length - 10)
          : currentEngMob;
      final normCandidate = candidateMobDigits.length >= 10
          ? candidateMobDigits.substring(candidateMobDigits.length - 10)
          : candidateMobDigits;
      if (normCandidate == normCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You cannot refer yourself. Referral rewards are only valid for external candidates."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final candidateEmail = _emailController.text.trim().toLowerCase();
    if (candidateEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Candidate email address is required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentEngEmail = SessionStore.current?.engineer.email?.trim().toLowerCase();
    if (currentEngEmail != null && currentEngEmail.isNotEmpty) {
      if (candidateEmail == currentEngEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You cannot refer yourself with your own email address."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final exp = double.tryParse(_expController.text.trim());

    context.read<ReferralBloc>().add(
          SubmitCandidateReferralRequested(
            jobOpeningId: _selectedJobId!,
            candidateName: _nameController.text.trim(),
            candidateMobile: fullCandidateMobile,
            candidateEmail: candidateEmail,
            currentCompany: _companyController.text.trim().isEmpty
                ? null
                : _companyController.text.trim(),
            totalExperienceYears: exp,
            resumeFile: _selectedResumeFile,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<ReferralBloc, ReferralState>(
      listener: (context, state) {
        if (state is ReferralLoaded) {
          if (state.submitSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.submitSuccessMessage!),
                backgroundColor: const Color(0xFF047857),
              ),
            );
            Navigator.of(context).pop();
          } else if (state.submitErrorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.submitErrorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (state is ReferralError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting =
            state is ReferralLoaded && state.isSubmitting;

        List<JobOpeningModel> jobOpenings = [];
        if (state is ReferralLoaded) {
          jobOpenings = state.jobOpenings;
        }

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            title: _buildAppBarTitle(),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildJobSelectionSection(jobOpenings),
                    if (widget.preselectedJob == null) const SizedBox(height: 20),

                    // Candidate Details
                    Text(
                      "Candidate Information",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 12),

                    AppTextFormField(
                      controller: _nameController,
                      label: "Candidate Full Name *",
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please enter candidate's name";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    CountryCodePhoneField(
                      controller: _mobileController,
                      selectedCountry: _selectedCountry,
                      onCountryChanged: (c) {
                        setState(() {
                          _selectedCountry = c;
                        });
                      },
                      labelText: "Candidate Mobile *",
                      alwaysFloatLabel: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please enter mobile number";
                        }
                        final clean = v.trim().replaceAll(RegExp(r'\s+'), '');
                        if (_selectedCountry.iso == 'IN' && clean.length != 10) {
                          return "Enter a valid 10-digit mobile number";
                        }
                        if (_selectedCountry.iso != 'IN' && (clean.length < 7 || clean.length > 15)) {
                          return "Enter a valid mobile number (7-15 digits)";
                        }
                        final currentEngMob = SessionStore.current?.engineer.mobileNo.trim().replaceAll(RegExp(r'\D'), '');
                        if (currentEngMob != null && currentEngMob.isNotEmpty) {
                          final normCurrent = currentEngMob.length >= 10
                              ? currentEngMob.substring(currentEngMob.length - 10)
                              : currentEngMob;
                          final normClean = clean.length >= 10
                              ? clean.substring(clean.length - 10)
                              : clean;
                          if (normClean == normCurrent) {
                            return "You cannot refer yourself. Enter candidate's number.";
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    AppTextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      label: "Candidate Email Address *",
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please enter candidate's email address";
                        }
                        final clean = v.trim().toLowerCase();
                        final emailRegex = RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
                        if (!emailRegex.hasMatch(clean)) {
                          return "Enter a valid email address (e.g. name@example.com)";
                        }
                        final currentEngEmail = SessionStore.current?.engineer.email?.trim().toLowerCase();
                        if (currentEngEmail != null && currentEngEmail.isNotEmpty && clean == currentEngEmail) {
                          return "You cannot refer yourself. Enter candidate's email.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppTextFormField(
                            controller: _companyController,
                            label: "Current Company",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppTextFormField(
                            controller: _expController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            label: "Exp (Yrs)",
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                if (double.tryParse(v.trim()) == null) {
                                  return "Invalid number";
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildResumeUploadCard(),
                    const SizedBox(height: 20),

                    AppTextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      label: "Recommendation Notes",
                    ),
                    const SizedBox(height: 24),

                    // Terms & Conditions Agreement
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _agreedToTerms
                              ? cs.primary.withValues(alpha: 0.4)
                              : cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (val) {
                                setState(() {
                                  _agreedToTerms = val ?? false;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface,
                                      height: 1.35,
                                    ),
                                children: [
                                  const TextSpan(
                                    text: "I confirm candidate's consent and agree to the ",
                                  ),
                                  TextSpan(
                                    text: "Referral Terms & Conditions",
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        ReferralTermsSheet.show(
                                          context,
                                          type: ReferralTermsType.candidate,
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (isSubmitting || !_agreedToTerms) ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Submit Candidate Referral",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBarTitle() {
    final job = widget.preselectedJob;
    if (job == null) {
      return const Text("Refer a Friend");
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Refer a Friend",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          job.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildJobSelectionSection(List<JobOpeningModel> jobOpenings) {
    if (widget.preselectedJob != null) {
      return const SizedBox.shrink();
    }

    final openJobOpenings = jobOpenings.where((j) => j.isOpen).toList();

    return AppDropdownField<String>(
      value: _selectedJobId,
      label: "Select Job Opening *",
      items: openJobOpenings.map((job) {
        return DropdownMenuItem<String>(
          value: job.id,
          child: Text(
            "${job.title} ${job.location != null ? '(${job.location})' : ''}",
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedJobId = val;
        });
      },
      validator: (v) => v == null ? "Please select a job opening" : null,
    );
  }

  Widget _buildResumeUploadCard() {
    return AppFileUploadCard(
      uploadLabel: 'Tap to Upload Candidate Resume',
      supportText: 'Supports PDF, DOC, DOCX up to 15 MB',
      fileName: _resumeFileName,
      fileSizeBytes: _resumeFileSize,
      onTap: _pickResume,
      onClear: () => setState(() {
        _selectedResumeFile = null;
        _resumeFileName = null;
        _resumeFileSize = null;
      }),
    );
  }
}
