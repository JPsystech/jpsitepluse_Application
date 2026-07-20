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

class _SplashViewState extends State<_SplashView> with TickerProviderStateMixin {
  late final AnimationController _revealCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // 2500ms reveal animation
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    // Continuous slow pulse
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _revealCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Start reveal, then loop pulse
    _revealCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat();
    });
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: cs.surface,
      body: BlocBuilder<SplashBloc, SplashState>(
        builder: (context, state) {
          if (state is SplashSecurityBlocked) {
            return _buildSecurityBlocked(context, state.message);
          }
          return _buildSplashContent(context);
        }
      ),
    );
  }

  Widget _buildSecurityBlocked(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: cs.error.withOpacity(0.3)),
            ),
            color: cs.errorContainer.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security_update_warning_rounded, color: cs.error, size: 56),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Security Alert",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.error,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onErrorContainer,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplashContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Stack(
      children: [
        // Telecom Watermarks
        Positioned(
          top: -80,
          right: -60,
          child: Icon(Icons.cell_tower_rounded, size: 350, color: cs.primary.withOpacity(0.03)),
        ),
        Positioned(
          bottom: 20,
          left: -80,
          child: Icon(Icons.sensors_rounded, size: 300, color: cs.primary.withOpacity(0.03)),
        ),
        
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulse Logo Animation
              ScaleTransition(
                scale: _scaleAnim,
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Rings
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 100 + (_pulseCtrl.value * 80),
                                height: 100 + (_pulseCtrl.value * 80),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.primary.withOpacity(
                                      (1.0 - _pulseCtrl.value) * 0.4,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 100 + (_pulseCtrl.value * 40),
                                height: 100 + (_pulseCtrl.value * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.primary.withOpacity(
                                    (1.0 - _pulseCtrl.value) * 0.1,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      // Core Logo Container (100x100)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.primary, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.location_on_rounded, color: cs.primary, size: 48),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Typography
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      Text(
                        "SitePulse",
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Field Operations Platform",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Smart Tower Inspection &\nWorkforce Management",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Sleek Bottom Loader
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                Text(
                  "Initializing Application...",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 120,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      backgroundColor: cs.primaryContainer,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "© JP Systech",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
