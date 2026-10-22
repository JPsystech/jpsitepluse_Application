import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:in_app_update/in_app_update.dart";

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

class _SplashViewState extends State<_SplashView>
    with TickerProviderStateMixin {
  late final AnimationController _revealCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // 2500ms reveal animation
    _revealCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    // Continuous slow pulse
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));

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

    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _revealCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Start reveal, then loop pulse
    _revealCtrl.forward().then((_) {
      if (mounted) _pulseCtrl.repeat();
    });

    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint("InAppUpdate check failed: $e");
    }
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
      body: BlocBuilder<SplashBloc, SplashState>(builder: (context, state) {
        if (state is SplashSecurityBlocked) {
          return _buildSecurityBlocked(context, state.message);
        }
        return _buildSplashContent(context);
      }),
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
              side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
            ),
            color: cs.errorContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security_update_warning_rounded,
                        color: cs.error, size: 56),
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
    final logoSize = (MediaQuery.sizeOf(context).width * 0.35).clamp(100.0, 160.0);

    return Stack(
      children: [
        // Telecom Watermarks
        Positioned(
          top: -80,
          right: -60,
          child: Icon(Icons.cell_tower_rounded,
              size: 350, color: cs.primary.withValues(alpha: 0.03)),
        ),
        Positioned(
          bottom: 20,
          left: -80,
          child: Icon(Icons.sensors_rounded,
              size: 300, color: cs.primary.withValues(alpha: 0.03)),
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: "logo",
                child: Center(
                  child: Image.asset(
                    'assets/icon/JP_SitePlus.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.business_center_rounded,
                      color: cs.primary,
                      size: logoSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "SitePulse",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      letterSpacing: 1.2,
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
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
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
