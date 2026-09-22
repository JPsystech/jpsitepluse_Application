import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_event.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_state.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/screens/job_detail_screen.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/screens/refer_candidate_screen.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/screens/submit_project_lead_screen.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/job_opening_card.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/project_inquiry_card.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/referral_earnings_banner.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/referral_terms_sheet.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/widgets/reward_card.dart';
import 'package:sitepulse_engineer/shared/widgets/error_state_view.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';

class ReferralsHomeScreen extends StatelessWidget {
  final int initialTabIndex;

  const ReferralsHomeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ReferralBloc()..add(const LoadReferralDataRequested()),
      child: _ReferralsHomeView(initialTabIndex: initialTabIndex),
    );
  }
}

class _ReferralsHomeView extends StatefulWidget {
  final int initialTabIndex;

  const _ReferralsHomeView({required this.initialTabIndex});

  @override
  State<_ReferralsHomeView> createState() => _ReferralsHomeViewState();
}

class _ReferralsHomeViewState extends State<_ReferralsHomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex > 2 ? 0 : widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final completer = Completer<void>();
    context.read<ReferralBloc>().add(
          LoadReferralDataRequested(silent: true, completer: completer),
        );
    await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  void _onSearchChanged(String query) {
    context.read<ReferralBloc>().add(SearchJobOpeningsRequested(query));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          "Referrals & Rewards",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: "Terms & Conditions",
            onPressed: () {
              ReferralTermsType type = ReferralTermsType.both;
              if (_tabController.index == 0) {
                type = ReferralTermsType.candidate;
              } else if (_tabController.index == 1) {
                type = ReferralTermsType.projectLead;
              }
              ReferralTermsSheet.show(context, type: type);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(
              icon: Icon(Icons.work_outline_rounded, size: 18),
              text: "Job Openings",
            ),
            Tab(
              icon: Icon(Icons.location_city_rounded, size: 18),
              text: "Project Leads",
            ),
            Tab(
              icon: Icon(Icons.stars_rounded, size: 18),
              text: "Rewards",
            ),
          ],
        ),
      ),
      body: BlocBuilder<ReferralBloc, ReferralState>(
        builder: (context, state) {
          if (state is ReferralInitial || state is ReferralLoading) {
            return _buildLoadingShimmer();
          }

          if (state is ReferralError) {
            return ErrorStateView(
              message: state.message,
              onRetry: () {
                context
                    .read<ReferralBloc>()
                    .add(const LoadReferralDataRequested());
              },
            );
          }

          if (state is ReferralLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildJobOpeningsTab(context, state),
                _buildProjectLeadsTab(context, state),
                _buildRewardsTab(context, state),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_tabController.index == 1) {
      // Project Leads Tab
      return FloatingActionButton.extended(
        heroTag: 'fab_project_lead',
        onPressed: () {
          final bloc = context.read<ReferralBloc>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: const SubmitProjectLeadScreen(),
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_business_rounded),
        label: const Text("New Project Lead"),
      );
    }
    return null;
  }

  Widget _buildJobOpeningsTab(BuildContext context, ReferralLoaded state) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search job title, role, location...",
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (state.jobOpenings.isEmpty)
            _buildEmptyTabState(
              icon: Icons.work_off_outlined,
              title: "No Open Positions",
              subtitle:
                  "There are currently no active job vacancies open for referrals. Check back soon!",
            )
          else
            ...state.jobOpenings.map(
              (job) {
                final referredCount = state.candidateReferrals
                    .where((c) => c.jobOpeningId == job.id)
                    .length;
                return JobOpeningCard(
                  job: job,
                  referredCount: referredCount,
                  onTap: () {
                    final bloc = context.read<ReferralBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(job: job, bloc: bloc),
                      ),
                    );
                  },
                  onReferTap: () {
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
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProjectLeadsTab(BuildContext context, ReferralLoaded state) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (state.projectInquiries.isEmpty)
            _buildEmptyTabState(
              icon: Icons.add_business_outlined,
              title: "No Project Leads Submitted",
              subtitle:
                  "Know a new client or construction project? Submit a project lead to earn commission bonuses!",
              actionLabel: "Submit First Lead",
              onActionTap: () {
                final bloc = context.read<ReferralBloc>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: const SubmitProjectLeadScreen(),
                    ),
                  ),
                );
              },
            )
          else
            ...state.projectInquiries.map(
              (inquiry) => ProjectInquiryCard(inquiry: inquiry),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRewardsTab(BuildContext context, ReferralLoaded state) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          ReferralEarningsBanner(
            totalPaid: state.totalPaidAmount,
            totalPayable: state.totalPayableAmount,
            totalPending: state.totalPendingAmount,
            activeCandidates: state.activeCandidatesCount,
            activeProjects: state.activeProjectInquiriesCount,
          ),
          const SizedBox(height: 16),
          if (state.rewards.isEmpty)
            _buildEmptyTabState(
              icon: Icons.stars_outlined,
              title: "No Rewards Yet",
              subtitle:
                  "When your candidate referrals join or your project leads convert into active contracts, rewards will be credited here!",
            )
          else
            ...state.rewards.map(
              (reward) => RewardCard(reward: reward),
            ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.6),
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.gavel_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              title: const Text(
                "Program Terms & Policies",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Review rules for candidate bonus & lead commissions",
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => ReferralTermsSheet.show(context,
                  type: ReferralTermsType.both),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }


  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onActionTap,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerBox(width: double.infinity, height: 160, borderRadius: 24),
        SizedBox(height: 20),
        ShimmerBox(width: double.infinity, height: 48, borderRadius: 14),
        SizedBox(height: 20),
        ShimmerBox(width: double.infinity, height: 140, borderRadius: 20),
        SizedBox(height: 14),
        ShimmerBox(width: double.infinity, height: 140, borderRadius: 20),
      ],
    );
  }
}
