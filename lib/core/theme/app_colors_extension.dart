import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.success,
    required this.warning,
    required this.successBg,
    required this.warningBg,
    required this.errorBg,
    required this.softShadow,
    required this.cardShadow,
    required this.primaryGradient,
  });

  final Color success;
  final Color warning;
  final Color successBg;
  final Color warningBg;
  final Color errorBg;
  final List<BoxShadow> softShadow;
  final List<BoxShadow> cardShadow;
  final LinearGradient primaryGradient;

  @override
  AppColorsExtension copyWith({
    Color? success,
    Color? warning,
    Color? successBg,
    Color? warningBg,
    Color? errorBg,
    List<BoxShadow>? softShadow,
    List<BoxShadow>? cardShadow,
    LinearGradient? primaryGradient,
  }) {
    return AppColorsExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      successBg: successBg ?? this.successBg,
      warningBg: warningBg ?? this.warningBg,
      errorBg: errorBg ?? this.errorBg,
      softShadow: softShadow ?? this.softShadow,
      cardShadow: cardShadow ?? this.cardShadow,
      primaryGradient: primaryGradient ?? this.primaryGradient,
    );
  }

  @override
  AppColorsExtension lerp(
      covariant ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      softShadow:
          BoxShadow.lerpList(softShadow, other.softShadow, t) ?? softShadow,
      cardShadow:
          BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t) ??
              primaryGradient,
    );
  }
}
