import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_terms_model.dart';
import 'package:sitepulse_engineer/features/referrals/data/repositories/referral_repository.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_bloc.dart';
import 'package:sitepulse_engineer/features/referrals/presentation/bloc/referral_state.dart';

enum ReferralTermsType {
  candidate,
  projectLead,
  both,
}

class ReferralTermsSheet extends StatefulWidget {
  final ReferralTermsType initialType;
  final ReferralTermsModel? terms;

  const ReferralTermsSheet({
    super.key,
    this.initialType = ReferralTermsType.both,
    this.terms,
  });

  static Future<void> show(
    BuildContext context, {
    ReferralTermsType type = ReferralTermsType.both,
    ReferralTermsModel? terms,
  }) {
    ReferralTermsModel? resolvedTerms = terms;
    if (resolvedTerms == null) {
      try {
        final bloc = context.read<ReferralBloc>();
        if (bloc.state is ReferralLoaded) {
          resolvedTerms = (bloc.state as ReferralLoaded).referralTerms;
        }
      } catch (_) {}
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReferralTermsSheet(
        initialType: type,
        terms: resolvedTerms,
      ),
    );
  }

  @override
  State<ReferralTermsSheet> createState() => _ReferralTermsSheetState();
}

class _ReferralTermsSheetState extends State<ReferralTermsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _showTabs;
  ReferralTermsModel? _terms;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _showTabs = widget.initialType == ReferralTermsType.both;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == ReferralTermsType.projectLead ? 1 : 0,
    );
    _terms = widget.terms;
    _fetchLiveTerms();
  }

  Future<void> _fetchLiveTerms() async {
    if (_terms == null) {
      setState(() => _isLoading = true);
    }
    try {
      final live = await ReferralRepository().getReferralTerms();
      if (mounted) {
        setState(() {
          _terms = live;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.gavel_rounded, color: cs.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (_showTabs)
            TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                  text: "Candidate Referrals",
                ),
                Tab(
                  icon: Icon(Icons.location_city_rounded, size: 18),
                  text: "Project Leads",
                ),
              ],
            ),
          const Divider(height: 1),
          Expanded(
            child: _showTabs
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCandidateTerms(context),
                      _buildProjectLeadTerms(context),
                    ],
                  )
                : widget.initialType == ReferralTermsType.candidate
                    ? _buildCandidateTerms(context)
                    : _buildProjectLeadTerms(context),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("I Understand"),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (widget.initialType) {
      case ReferralTermsType.candidate:
        return (_terms?.candidateTermsTitle.isNotEmpty == true)
            ? _terms!.candidateTermsTitle
            : "Candidate Referral Terms";
      case ReferralTermsType.projectLead:
        return (_terms?.projectLeadTermsTitle.isNotEmpty == true)
            ? _terms!.projectLeadTermsTitle
            : "Project Lead Terms";
      case ReferralTermsType.both:
        return "Referrals & Rewards Terms";
    }
  }

  Widget _buildCandidateTerms(BuildContext context) {
    if (_terms != null && _terms!.candidateTermsContent.trim().isNotEmpty) {
      return _buildFormattedTermsContent(
        context,
        rawContent: _terms!.candidateTermsContent,
        defaultIcon: Icons.verified_user_outlined,
      );
    }

    // Built-in offline fallback
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionCard(
          context,
          icon: Icons.verified_user_outlined,
          title: "1. Candidate Eligibility",
          items: const [
            "New Applicants Only: The candidate must not have applied, interviewed, or been in the active recruitment system in the last 6 months (180 days).",
            "Candidate Consent: You confirm that you have obtained the candidate's explicit consent before submitting their details and resume.",
            "No Self-Referrals: Engineers cannot refer themselves or currently active internal employees / contractors.",
            "Open Positions Only: Referrals must be submitted for job positions currently marked as OPEN.",
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.timer_outlined,
          title: "2. Priority & Validity Window",
          items: const [
            "First-to-Refer Rule: If multiple engineers refer the same candidate, referral credit and bonus belong to the earliest timestamped submission.",
            "6 Months Validity: A candidate referral remains valid for 6 months. If hired after 6 months without ongoing interview activity, referral credit expires.",
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.payments_outlined,
          title: "3. Bonus Payout & Milestones",
          items: const [
            "Probation & Retention: Referral bonus is earned after the candidate successfully joins and completes their minimum service period (30–90 days probation).",
            "Active Employment: The referring engineer must be an active employee in good standing when the bonus is disbursed.",
            "Disbursement: Bonuses are credited to the engineer's earnings ledger / payroll account subject to statutory deductions.",
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.admin_panel_settings_outlined,
          title: "4. Company Discretion",
          items: const [
            "Management reserves the right to review, update, or terminate bonus amounts, eligibility criteria, or program rules at any time.",
          ],
        ),
      ],
    );
  }

  Widget _buildProjectLeadTerms(BuildContext context) {
    if (_terms != null && _terms!.projectLeadTermsContent.trim().isNotEmpty) {
      return _buildFormattedTermsContent(
        context,
        rawContent: _terms!.projectLeadTermsContent,
        defaultIcon: Icons.business_outlined,
      );
    }

    // Built-in offline fallback
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionCard(
          context,
          icon: Icons.business_outlined,
          title: "1. Lead Authenticity & Scope",
          items: const [
            "Genuine New Business: The project or client must be a newly identified opportunity that the company is not already in active commercial negotiations with.",
            "Accurate Contact Details: The engineer must provide valid client information (contact person, phone number, site name, and site address).",
            "First-Submission Priority: In case of duplicate leads for the same site or client, priority goes to the earliest verified submission.",
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.track_changes_outlined,
          title: "2. Verification & Lifecycle",
          items: const [
            "Sales Pipeline: The BD / Sales team will review and contact the lead (New -> Contacted -> In Progress -> Converted or Lost).",
            "Deal Conversion: A lead is officially considered CONVERTED only after a formal contract / work order is signed and the initial advance deposit is received.",
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.account_balance_wallet_outlined,
          title: "3. Commission & Payouts",
          items: const [
            "Approved Milestone Payments: Commission payouts are calculated based on approved contract values and released in alignment with client payment milestones.",
            "Active Status: The engineer must be an active employee in good standing at the time of payout.",
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          context,
          icon: Icons.shield_outlined,
          title: "4. Ethics & Anti-Fraud Policy",
          items: const [
            "Any fake, fraudulent, or spam submissions made with malicious intent will lead to immediate program disqualification and internal disciplinary review.",
          ],
        ),
      ],
    );
  }

  Widget _buildFormattedTermsContent(
    BuildContext context, {
    required String rawContent,
    required IconData defaultIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final lines = rawContent.split('\n');
    final sections = <_TermsSectionData>[];

    String currentTitle = '';
    final currentItems = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final isHeader = trimmed.startsWith('#') ||
          RegExp(r'^\d+[\.\)]\s+[A-Z]').hasMatch(trimmed) ||
          trimmed.endsWith(':');

      if (isHeader) {
        if (currentTitle.isNotEmpty || currentItems.isNotEmpty) {
          sections.add(_TermsSectionData(
            title: currentTitle.isEmpty ? 'Policy Details' : currentTitle,
            items: List.from(currentItems),
          ));
          currentItems.clear();
        }
        currentTitle = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
      } else {
        final cleaned = trimmed.replaceAll(RegExp(r'^[\*\-\•]\s*'), '');
        currentItems.add(cleaned);
      }
    }

    if (currentTitle.isNotEmpty || currentItems.isNotEmpty) {
      sections.add(_TermsSectionData(
        title: currentTitle.isEmpty ? 'Terms & Conditions' : currentTitle,
        items: List.from(currentItems),
      ));
    }

    if (sections.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Text(
              rawContent,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final sec = sections[index];
        return _buildSectionCard(
          context,
          icon: defaultIcon,
          title: sec.title,
          items: sec.items,
        );
      },
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant)),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.35,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TermsSectionData {
  final String title;
  final List<String> items;

  _TermsSectionData({required this.title, required this.items});
}
