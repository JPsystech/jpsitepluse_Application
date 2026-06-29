import "package:flutter/material.dart";

class AppTheme {
  static const Color navy = Color(0xFF0B1F3B);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color bg = Color(0xFFF5F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0x1A0B1F3B);
  static const Color muted = Color(0xFF64748B);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFF3C4);
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerBg = Color(0xFFFEE2E2);

  // Premium Tokens
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: navy.withAlpha(12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: navy.withAlpha(10),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  static LinearGradient primaryGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky, Color(0xFF0284C7)],
  );

  static ThemeData light() {
    final baseScheme = ColorScheme.fromSeed(seedColor: sky, brightness: Brightness.light).copyWith(
      primary: sky,
      onPrimary: Colors.white,
      surface: card,
      onSurface: navy,
      outline: border,
      error: danger,
      errorContainer: dangerBg,
      onErrorContainer: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: bg,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: navy,
      displayColor: navy,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: navy,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy, letterSpacing: -0.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        elevation: 0,
        height: 72,
        indicatorColor: const Color(0x1A0EA5E9),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
      ),
      cardTheme: const CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0x0D0B1F3B), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x0D0B1F3B), thickness: 1, space: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: sky, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sky,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: sky,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return sky;
          return null;
        }),
      ),
    );
  }
}
