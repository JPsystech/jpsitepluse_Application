import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/features/referrals/data/services/referral_service.dart';

/// Tracks new job openings per engineer, with a local fallback for offline use.
class ReferralJobBadgeService {
  ReferralJobBadgeService._();

  static final instance = ReferralJobBadgeService._();
  final ValueNotifier<int> unseenCount = ValueNotifier<int>(0);
  bool _isRefreshing = false;

  String _storageKey(String engineerId) => 'referral_jobs_seen_at_$engineerId';

  Future<void> refresh({required String engineerId}) async {
    if (engineerId.trim().isEmpty || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final service = ReferralService();
      final results = await Future.wait([service.getJobOpenings(), service.getJobOpeningsSeenAt()]);
      final jobs = results[0] as List;
      final serverSeenAt = results[1] as DateTime?;
      final prefs = await SharedPreferences.getInstance();
      // Read after the request too: the engineer may have opened Refer & Earn
      // while this refresh was in flight.
      final seenAtMs = prefs.getInt(_storageKey(engineerId));
      final localSeenAt = seenAtMs == null
          ? DateTime.now().subtract(const Duration(days: 7))
          : DateTime.fromMillisecondsSinceEpoch(seenAtMs);
      final seenAt = serverSeenAt != null && serverSeenAt.isAfter(localSeenAt) ? serverSeenAt : localSeenAt;
      unseenCount.value = jobs.where((job) {
        final postedAt = DateTime.tryParse(job.publishedAt ?? job.createdAt ?? '');
        if (postedAt == null || !job.isOpen) return false;
        return postedAt.isAfter(weekAgo) && postedAt.isAfter(seenAt);
      }).length;
    } catch (_) {
      // Keep the last visible count if jobs cannot be fetched right now.
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> markSeen({required String engineerId}) async {
    if (engineerId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey(engineerId), DateTime.now().millisecondsSinceEpoch);
    try {
      await ReferralService().markJobOpeningsSeen();
    } catch (_) {
      // Local state still prevents a badge from reappearing while offline.
    }
    unseenCount.value = 0;
  }
}
