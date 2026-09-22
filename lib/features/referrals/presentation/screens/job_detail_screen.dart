import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/candidate_referral_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/job_opening_model.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_event.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_state.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/screens/refer_candidate_screen.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/candidate_referral_card.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/referral_terms_sheet.dart';

class JobDetailScreen extends StatelessWidget {
  final JobOpeningModel job;
  final ReferralBloc? bloc;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: _JobDetailScreenView(job: job),
      );
    }

    try {
      final existing = context.read<ReferralBloc>();
      return BlocProvider.value(
        value: existing,
        child: _JobDetailScreenView(job: job),
      );
    } catch (_) {
      return BlocProvider(
        create: (_) => ReferralBloc()..add(const LoadReferralDataRequested()),
        child: _JobDetailScreenView(job: job),
      );
    }
  }
}

class _JobDetailScreenView extends StatelessWidget {
  final JobOpeningModel job;

  const _JobDetailScreenView({required this.job});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<ReferralBloc, ReferralState>(
      builder: (context, state) {
        List<CandidateReferralModel> myReferrals = [];
        if (state is ReferralLoaded) {
          myReferrals = state.candidateReferrals
              .where((c) => c.jobOpeningId == job.id)
              .toList();
        }

        final referralTabTitle = myReferrals.isNotEmpty
            ? "My Referrals (${myReferrals.length})"
            : "My Referrals";

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              title: const Text("Job Opening Details"),
              centerTitle: true,
              bottom: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.description_outlined, size: 18),
                    text: "Job Overview",
                  ),
                  Tab(
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    text: referralTabTitle,
                  ),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  _buildJobOverviewTab(context),
                  _buildMyReferralsTab(context, myReferrals),
                ],
              ),
            ),
            bottomNavigationBar: job.isOpen
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final bloc = context.read<ReferralBloc>();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: bloc,
                              child: ReferCandidateScreen(preselectedJob: job),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        myReferrals.isEmpty
                            ? "Refer Candidate for this Role"
                            : "+ Refer Another Candidate",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildJobOverviewTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                          ),
                          if (job.department != null &&
                              job.department!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              job.department!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (job.bonusAmount != null && job.bonusAmount! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "REFERRAL BONUS",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              currencyFormatter.format(job.bonusAmount),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusBadge(context),
                    if (job.location != null && job.location!.isNotEmpty)
                      _buildDetailTag(
                        context,
                        icon: Icons.location_on_outlined,
                        label: job.location!,
                      ),
                    _buildDetailTag(
                      context,
                      icon: Icons.timeline_rounded,
                      label: job.experienceRange,
                    ),
                    if (job.designation != null &&
                        job.designation!.isNotEmpty)
                      _buildDetailTag(
                        context,
                        icon: Icons.badge_outlined,
                        label: job.designation!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (job.isOnHold) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      color: Color(0xFFB45309), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Referrals for this position are temporarily on hold. New candidate submissions are currently paused.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (job.isClosed) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: Color(0xFF6B7280), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "This position has been closed. You can track any previously submitted candidates in the 'My Referrals' tab above.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Description section
          Text(
            "Job Description & Requirements",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                (job.description != null && job.description!.isNotEmpty)
                    ? job.description!
                    : "No specific requirements specified for this role. Qualified candidates with relevant field engineering or technical experience are welcome to apply.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: cs.onSurface,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Referral Policy Card
          Card(
            elevation: 0,
            color: const Color(0xFFF0FDF4),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFBBF7D0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF047857), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "How Referral Bonus Works",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Refer a candidate friend by uploading their resume. Once they successfully clear screening, interview rounds, and join the team, the referral bonus will be credited to your earnings ledger.",
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF047857),
                          ),
                        ),
                        SizedBox(height: 10),
                        InkWell(
                          onTap: () {
                            ReferralTermsSheet.show(
                              context,
                              type: ReferralTermsType.candidate,
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "View Full Referral Policy & T&C",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: Color(0xFF047857)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMyReferralsTab(
      BuildContext context, List<CandidateReferralModel> referrals) {
    final cs = Theme.of(context).colorScheme;

    if (referrals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_disabled_outlined,
                  size: 48,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "No Referrals for this Position",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                job.isOpen
                    ? "You haven't referred any candidate for '${job.title}' yet. Submit a qualified friend's profile to earn the referral bonus!"
                    : "No referrals were submitted for '${job.title}' before this position was ${job.isOnHold ? 'placed on hold' : 'closed'}.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              if (job.isOpen) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    final bloc = context.read<ReferralBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: bloc,
                          child: ReferCandidateScreen(preselectedJob: job),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text("Refer Candidate Now"),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Showing ${referrals.length} candidate${referrals.length > 1 ? 's' : ''} referred by you for this position.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...referrals.map((r) => CandidateReferralCard(referral: r)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (job.isOpen) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      textColor = const Color(0xFF047857);
      icon = Icons.check_circle_outline_rounded;
      label = "OPEN";
    } else if (job.isOnHold) {
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFFB45309);
      icon = Icons.pause_circle_outline_rounded;
      label = "ON HOLD";
    } else {
      bgColor = const Color(0xFFF3F4F6);
      borderColor = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF6B7280);
      icon = Icons.lock_outline_rounded;
      label = "CLOSED";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTag(BuildContext context,
      {required IconData icon, required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
