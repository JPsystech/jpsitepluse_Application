import "dart:async";

import "package:flutter/material.dart";

import "../../core/session_store.dart";
import "../../core/terms_store.dart";
import "../../routes/app_routes.dart";
import "../../theme/app_theme.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 300), () async {
      await SessionStore.load();
      final accepted = await TermsStore.isAccepted();
      if (!mounted) return;
      final next = SessionStore.current == null ? AppRoutes.login : (accepted ? AppRoutes.app : AppRoutes.terms);
      Navigator.of(context).pushReplacementNamed(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.sky.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.location_on_outlined, color: AppTheme.navy, size: 34),
              ),
              const SizedBox(height: 18),
              const Text(
                "JP SitePulse",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              const Text(
                "Field tracking & attendance",
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 22),
              const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ],
          ),
        ),
      ),
    );
  }
}
