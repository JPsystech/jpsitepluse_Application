import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

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
              backgroundColor: Theme.of(context).colorScheme.error,
            ));
          }
        },
        child: const _SplashView(),
      ),
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.location_on_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  "JP SitePulse",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  "Field tracking & attendance",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant, 
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
                const SizedBox(height: 48),
                SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Theme.of(context).colorScheme.primary,
                      strokeCap: StrokeCap.round,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
