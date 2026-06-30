import "package:flutter/material.dart";

import "app_colors_extension.dart";

class AppTheme {
  static const Color _navy = Color(0xFF0B1F3B);
  static const Color _sky = Color(0xFF0EA5E9);
  static const Color _bg = Color(0xFFF5F7FB);
  static const Color _card = Colors.white;
  static const Color _border = Color(0x1A0B1F3B);
  static const Color _muted = Color(0xFF64748B);

  // Semantic Colors
  static const Color _success = Color(0xFF10B981);
  static const Color _successBg = Color(0xFFDCFCE7);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _warningBg = Color(0xFFFFF3C4);
  static const Color _danger = Color(0xFFE11D48);
  static const Color _dangerBg = Color(0xFFFEE2E2);

  // Premium Tokens
  static final List<BoxShadow> _softShadow = [
    BoxShadow(
      color: _navy.withAlpha(12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: _navy.withAlpha(10),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  static final LinearGradient _primaryGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_sky, Color(0xFF0284C7)],
  );

  static ThemeData light() {
    final baseScheme =
        ColorScheme.fromSeed(seedColor: _sky, brightness: Brightness.light)
            .copyWith(
      primary: _sky,
      onPrimary: Colors.white,
      surface: _card,
      onSurface: _navy,
      outline: _border,
      error: _danger,
      errorContainer: _dangerBg,
      onErrorContainer: _danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: _bg,
      extensions: [
        AppColorsExtension(
          success: _success,
          warning: _warning,
          successBg: _successBg,
          warningBg: _warningBg,
          errorBg: _dangerBg,
          softShadow: _softShadow,
          cardShadow: _cardShadow,
          primaryGradient: _primaryGradient,
        ),
      ],
    );

    final textTheme = base.textTheme.apply(
      bodyColor: _navy,
      displayColor: _navy,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _navy,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _navy,
            letterSpacing: -0.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _card,
        elevation: 0,
        height: 72,
        indicatorColor: const Color(0x1A0EA5E9),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
      ),
      cardTheme: const CardThemeData(
        color: _card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0x0D0B1F3B), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
          color: Color(0x0D0B1F3B), thickness: 1, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card,
        hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
        prefixIconColor: _muted,
        suffixIconColor: _muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _sky, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _sky,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _navy,
          side: const BorderSide(color: _border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _sky,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _sky;
          return null;
        }),
      ),
    );
  }
}
