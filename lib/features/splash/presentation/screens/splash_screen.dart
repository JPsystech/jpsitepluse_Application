import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/theme/app_theme.dart";
import "package:sitepulse_engineer/features/splash/presentation/bloc/splash_bloc.dart";

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SplashBloc()..add(SplashInitialized()),
      child: BlocListener<SplashBloc, SplashState>(
        listener: (context, state) {
          if (state is SplashSuccess) {
            Navigator.of(context).pushReplacementNamed(state.nextRoute);
          } else if (state is SplashError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error: ${state.errorMessage}"),
              backgroundColor: AppTheme.danger,
            ));
          }
        },
        child: const _SplashView(),
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

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
