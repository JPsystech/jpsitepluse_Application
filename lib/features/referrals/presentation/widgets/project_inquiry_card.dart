import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/project_inquiry_model.dart';

class ProjectInquiryCard extends StatelessWidget {
  final ProjectInquiryModel inquiry;

  const ProjectInquiryCard({
    super.key,
    required this.inquiry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final isConverted = inquiry.status.toUpperCase() == 'CONVERTED';
    final isRejected = inquiry.status.toUpperCase() == 'REJECTED' ||
        inquiry.status.toUpperCase() == 'DUPLICATE';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isConverted
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_city_rounded,
                    color: cs.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inquiry.clientName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (inquiry.siteName != null &&
                          inquiry.siteName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            inquiry.siteName!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(context),
              ],
            ),
            const SizedBox(height: 14),
            _buildStatusStepper(context),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (inquiry.contactPerson != null ||
                      inquiry.contactMobile != null)
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${inquiry.contactPerson ?? 'Contact'} • ${inquiry.contactMobile ?? ''}",
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (inquiry.city != null || inquiry.state != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [inquiry.city, inquiry.state]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(", "),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (inquiry.estimatedValue != null ||
                      inquiry.expectedBonusAmount != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (inquiry.estimatedValue != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Est. Value",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                currencyFormatter
                                    .format(inquiry.estimatedValue),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        if (inquiry.expectedBonusAmount != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                "Expected Bonus",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                currencyFormatter
                                    .format(inquiry.expectedBonusAmount),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (inquiry.adminRemarks != null &&
                inquiry.adminRemarks!.isNotEmpty) ...[
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
                        "Admin: ${inquiry.adminRemarks}",
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

  Widget _buildStatusBadge(BuildContext context) {
    Color bg = const Color(0xFFEFF6FF);
    Color fg = const Color(0xFF1D4ED8);

    switch (inquiry.status.toUpperCase()) {
      case 'NEW':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'CONTACTED':
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF6D28D9);
        break;
      case 'QUALIFIED':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        break;
      case 'CONVERTED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        break;
      case 'REJECTED':
      case 'DUPLICATE':
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
        inquiry.status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusStepper(BuildContext context) {
    final stages = ['New Lead', 'Contacted', 'Qualified', 'Converted'];
    final currentStep = inquiry.statusStep;
    final isRejected = inquiry.status.toUpperCase() == 'REJECTED' ||
        inquiry.status.toUpperCase() == 'DUPLICATE';

    if (isRejected) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 16),
            const SizedBox(width: 6),
            Text(
              inquiry.status.toUpperCase() == 'DUPLICATE'
                  ? "Marked as Duplicate Lead"
                  : "Lead Closed / Not Qualified",
              style: const TextStyle(
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
