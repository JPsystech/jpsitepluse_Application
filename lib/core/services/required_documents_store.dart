import "package:flutter/foundation.dart";

import "package:sitepulse_engineer/features/onboarding/data/services/onboarding_service.dart";

/// Cached server-defined document requirements for the signed-in engineer.
/// The backend is the source of truth because requirements are configured per
/// vendor department in Departments & Documents settings.
class RequiredDocumentsStore {
  RequiredDocumentsStore._();

  static final ValueNotifier<Set<String>?> requiredTypes =
      ValueNotifier<Set<String>?>(null);

  static Future<void> refresh({String? token}) async {
    try {
      final status =
          await OnboardingService().getOnboardingStatus(token: token);
      requiredTypes.value = status.requiredDocuments.toSet();
    } catch (_) {
      // Keep the previous successful value. A null value tells callers that
      // requirements are unavailable rather than falling back to old rules.
    }
  }
}
