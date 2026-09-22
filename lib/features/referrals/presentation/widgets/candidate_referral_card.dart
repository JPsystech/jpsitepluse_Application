import 'package:flutter/material.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/candidate_referral_model.dart';

class CandidateReferralCard extends StatelessWidget {
  final CandidateReferralModel referral;

  const CandidateReferralCard({
    super.key,
    required this.referral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRejected = referral.currentStage.toUpperCase() == 'REJECTED';
    final isJoined = referral.currentStage.toUpperCase() == 'JOINED';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isJoined
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isRejected
                  ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                  : cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    referral.candidateName.isNotEmpty
                        ? referral.candidateName[0].toUpperCase()
                        : 'C',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        referral.candidateName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        referral.jobTitle ?? 'Job Position',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildStageBadge(context),
              ],
            ),
            const SizedBox(height: 14),
            _buildStageStepper(context),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        referral.candidateMobile,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (referral.totalExperienceYears != null) ...[
                        const Spacer(),
                        Icon(Icons.work_history_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          "${referral.totalExperienceYears} Yrs Exp",
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (referral.currentCompany != null &&
                      referral.currentCompany!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Current: ${referral.currentCompany}",
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (referral.adminRemarks != null &&
                referral.adminRemarks!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isRejected
                      ? const Color(0xFFFEF2F2)
                      : cs.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRejected
                        ? const Color(0xFFFCA5A5)
                        : cs.secondaryContainer,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: isRejected
                          ? const Color(0xFFDC2626)
                          : cs.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Admin: ${referral.adminRemarks}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isRejected
                              ? const Color(0xFFDC2626)
                              : cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStageBadge(BuildContext context) {
    Color bg = const Color(0xFFEFF6FF); // Blue 50
    Color fg = const Color(0xFF1D4ED8); // Blue 700

    switch (referral.currentStage.toUpperCase()) {
      case 'SUBMITTED':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'SCREENING':
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF6D28D9);
        break;
      case 'INTERVIEW':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        break;
      case 'SELECTED':
      case 'JOINED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        referral.currentStage.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStageStepper(BuildContext context) {
    final stages = ['Applied', 'Screening', 'Interview', 'Joined'];
    final currentStep = referral.stageStep;
    final isRejected = referral.currentStage.toUpperCase() == 'REJECTED';

    if (isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 16),
            SizedBox(width: 6),
            Text(
              "Application Not Selected",
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: List.generate(stages.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isLineActive = stepIndex < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isLineActive
                  ? const Color(0xFF10B981)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final isPassed = stepIndex <= currentStep;
        final isCurrent = stepIndex == currentStep;

        return Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? const Color(0xFF10B981)
                    : Colors.grey.withValues(alpha: 0.2),
                border: isCurrent
                    ? Border.all(color: const Color(0xFF047857), width: 2)
                    : null,
              ),
              child: isPassed
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              stages[stepIndex],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isPassed ? const Color(0xFF047857) : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }
}
