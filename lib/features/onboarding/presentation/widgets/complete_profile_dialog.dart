import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';
import '../../data/models/onboarding_status_model.dart';
import '../../data/services/onboarding_service.dart';
import '../screens/complete_profile_screen.dart';

class CompleteProfileDialog extends StatelessWidget {
  final OnboardingStatusModel status;
  final VoidCallback onDismissForToday;
  final VoidCallback onProceed;

  const CompleteProfileDialog({
    super.key,
    required this.status,
    required this.onDismissForToday,
    required this.onProceed,
  });

  static const String dismissedKeyPrefix = 'sitepulse_onboarding_dismissed_';

  static Future<void> showIfNeeded(BuildContext context) async {
    final session = SessionStore.current;
    if (session == null || session.token.trim().isEmpty) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final lastDismissed =
        prefs.getString('$dismissedKeyPrefix${session.engineer.id}');
    if (lastDismissed == todayStr) {
      // User dismissed for today
      return;
    }

    try {
      final status =
          await OnboardingService().getOnboardingStatus(token: session.token);
      if (status.isProfileComplete) return;

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => CompleteProfileDialog(
          status: status,
          onDismissForToday: () async {
            await prefs.setString(
                '$dismissedKeyPrefix${session.engineer.id}', todayStr);
            if (dialogCtx.mounted) {
              Navigator.of(dialogCtx).pop();
            }
          },
          onProceed: () {
            Navigator.of(dialogCtx).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CompleteProfileScreen()),
            );
          },
        ),
      );
    } catch (_) {
      // Silently ignore network failures on startup
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.badge_outlined,
                color: colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Complete Profile",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Action Required",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              "Please complete your profile and upload compliance documents to unlock attendance punch-in.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Progress bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Completion Progress",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "${status.completionPercentage}%",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (status.completionPercentage / 100.0)
                          .clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        status.completionPercentage > 70
                            ? Colors.green
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (status.missingFields.isNotEmpty) ...[
              Text(
                "Missing Information:",
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.missingFields
                    .map(OnboardingStatusModel.fieldDisplayName)
                    .join(" • "),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (status.missingDocuments.isNotEmpty) ...[
              Text(
                "Missing Documents (${status.department ?? 'General'}):",
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.missingDocuments
                    .map(OnboardingStatusModel.docDisplayName)
                    .join(" • "),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_clock_rounded,
                    size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Punch-in is locked until details are submitted.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: onDismissForToday,
          child: Text(
            "Remind Tomorrow",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: onProceed,
          child: const Text("Complete Profile"),
        ),
      ],
    );
  }
}
