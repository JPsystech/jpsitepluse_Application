import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sitepulse_engineer/features/referrals/data/models/referral_reward_model.dart';

class RewardCard extends StatelessWidget {
  final ReferralRewardModel reward;

  const RewardCard({
    super.key,
    required this.reward,
  });

  String _formatDateTime(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "";
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
      }
    } catch (_) {}
    return rawDate;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final isPaid = reward.isPaid;
    final isPayable = reward.isPayable;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : (isPayable
                  ? const Color(0xFF0EA5E9).withValues(alpha: 0.3)
                  : const Color(0x1A0B1F3B)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F3B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                    color: isPaid
                        ? const Color(0xFFDCFCE7) // Soft Mint
                        : (isPayable
                            ? const Color(0xFFE0F2FE) // Soft Sky Blue
                            : const Color(0xFFFEF3C7)), // Soft Amber
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.check_circle_rounded
                        : (isPayable
                            ? Icons.account_balance_wallet_rounded
                            : Icons.schedule_rounded),
                    color: isPaid
                        ? const Color(0xFF059669)
                        : (isPayable
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFD97706)),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.sourceTitle ?? reward.sourceLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B1F3B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reward.sourceType == 'HIRING_REFERRAL'
                            ? "Candidate Referral Bonus"
                            : "Project Inquiry Commission",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormatter.format(reward.amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isPaid
                        ? const Color(0xFF059669)
                        : const Color(0xFF0B1F3B),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBadge(),
                if (reward.paidAt != null && isPaid)
                  Text(
                    "Paid on ${_formatDateTime(reward.paidAt)}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (reward.createdAt != null)
                  Text(
                    "Initiated ${_formatDateTime(reward.createdAt)}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            if (reward.paymentReference != null &&
                reward.paymentReference!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 13,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Ref: ${reward.paymentReference}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (reward.remarks != null && reward.remarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reward.remarks!,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    IconData icon = Icons.info_outline_rounded;

    switch (reward.status.toUpperCase()) {
      case 'PAID':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF059669);
        icon = Icons.check_circle_rounded;
        break;
      case 'PAYABLE':
      case 'APPROVED':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        icon = Icons.account_balance_wallet_rounded;
        break;
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            reward.status.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

