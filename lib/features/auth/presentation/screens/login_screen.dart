import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

import "package:sitepulse_engineer/core/config/api_config.dart";
import "package:sitepulse_engineer/core/storage/terms_store.dart";
import "package:sitepulse_engineer/core/storage/mpin_store.dart";
import "package:sitepulse_engineer/core/storage/credential_store.dart";
import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/storage/offline_session_cache.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/shared/widgets/app_text_field.dart";
import "package:sitepulse_engineer/shared/widgets/primary_button.dart";
import "package:sitepulse_engineer/shared/utils/dialog_utils.dart";
import "package:pinput/pinput.dart";

import "package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart";
import "package:sitepulse_engineer/features/auth/presentation/bloc/auth_bloc.dart";

import "../../data/services/auth_service.dart";
import "package:sitepulse_engineer/core/error/error_handler.dart";

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: const LoginScreenView(),
    );
  }
}

class LoginScreenView extends StatefulWidget {
  const LoginScreenView({super.key});

  @override
  State<LoginScreenView> createState() => _LoginScreenViewState();
}

class _LoginScreenViewState extends State<LoginScreenView> {
  final vendorCodeCtrl = TextEditingController();
  final empCodeCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final serverUrlCtrl = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;
  String? error;
  int _currentStep = 0;
  bool isFetchingBranding = false;
  String? vendorLogoUrl;
  String? vendorName;

  bool isMpinMode = false;
  bool isResettingMpin = false;
  bool isLoadingInitialState = true;
  String _pin = "";
  String _engineerName = "";
  bool isAutoLoggingIn = false;

  @override
  void initState() {
    super.initState();
    serverUrlCtrl.text = productionApiBaseUrl;
    _loadSavedVendorCode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (SessionStore.sessionExpired) {
        SessionStore.sessionExpired = false;
        
        // Suppress any duplicate error snackbars emitted by feature BLoCs
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please login again.'),
          ),
        );
      }
    });
  }

  Future<void> _loadSavedVendorCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString("sitepulse_engineer_vendor_code");
    if (savedCode != null && savedCode.trim().isNotEmpty) {
      setState(() {
        vendorCodeCtrl.text = savedCode.trim();
      });

      final hasMpin = await MpinStore.hasMpin();
      final creds = await CredentialStore.getCredentials();
      final session = SessionStore.current;

      if (hasMpin || (session?.hasMpin ?? false)) {
        setState(() {
          isMpinMode = true;
          _engineerName = creds?['engineerName'] ?? "Engineer";
        });
      }

      // Automatically proceed to fetch branding and show Step 2
      _nextStep();
    } else {
      setState(() {
        isLoadingInitialState = false;
      });
    }
  }

  Future<void> _nextStep() async {
    setState(() {
      error = null;
    });
    final vendor = vendorCodeCtrl.text.trim();
    if (vendor.isEmpty) {
      setState(() {
        error = "Enter Vendor Code to continue";
      });
      return;
    }

    setState(() {
      isFetchingBranding = true;
    });

    try {
      final baseUrl = await resolveApiBaseUrl();
      final uri = Uri.parse("$baseUrl/api/v1/public/branding/$vendor");
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          vendorName = data['company_name'];
          if (data['logo_url'] != null &&
              data['logo_url'].toString().isNotEmpty) {
            vendorLogoUrl = "$baseUrl${data['logo_url']}";
          } else {
            vendorLogoUrl = null;
          }
        });
      } else if (response.statusCode == 404) {
        setState(() {
          error = "Invalid Vendor Code. Please try again.";
          isFetchingBranding = false;
          isLoadingInitialState = false;
        });
        return;
      } else {
        setState(() {
          error = "Failed to verify Vendor Code.";
          isFetchingBranding = false;
          isLoadingInitialState = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        error = "Network error. Proceeding offline.";
      });
      // Do not return here. Let the local session initialize so the user can use MPIN offline.
    }

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("sitepulse_engineer_vendor_code", vendor);

    final hasMpin = await MpinStore.hasMpin();
    final creds = await CredentialStore.getCredentials();
    final session = SessionStore.current;

    if (!mounted) return;

    setState(() {
      if (hasMpin || (session?.hasMpin ?? false)) {
        isMpinMode = true;
        _engineerName = creds?['engineerName'] ?? "Engineer";
        // Clear the network warning since we can proceed with offline MPIN
        if (error == "Network error. Proceeding offline.") {
          error = null;
        }
      } else {
        isMpinMode = false;
      }
      isFetchingBranding = false;
      isLoadingInitialState = false;
      _currentStep = 1;
    });
  }

  void _previousStep() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("sitepulse_engineer_vendor_code");

    setState(() {
      error = null;
      _currentStep = 0;
      vendorCodeCtrl.clear();
      vendorName = null;
      vendorLogoUrl = null;
    });
  }

  Future<void> _verifyMpinAndLogin() async {
    setState(() => isAutoLoggingIn = true);
    bool isValid = await MpinStore.verifyMpin(_pin);
    if (!isValid && SessionStore.current != null) {
      try {
        await AuthService().verifyMpin(SessionStore.current!.token, _pin);
        isValid = true;
        await MpinStore.setMpin(_pin); // Save locally for future use
      } catch (e) {
        isValid = false;
      }
    }
    if (isValid) {
      if (SessionStore.current != null) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.app, (route) => false);
        }
        return;
      }

      // Session is null (user logged out). Try to restore offline session.
      final offlineSession = await OfflineSessionCache.get();
      if (offlineSession != null) {
        await SessionStore.set(offlineSession);
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.app, (route) => false);
        }
        return;
      }

      final creds = await CredentialStore.getCredentials();
      if (creds != null) {
        // We simulate a form submission for the bloc
        empCodeCtrl.text = creds['empCode']!;
        passwordCtrl.text = creds['password']!;
        rememberMe = true;
        submit();
      } else {
        setState(() {
          error = "No saved credentials found. Please sign in with password.";
          _pin = "";
          isAutoLoggingIn = false;
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        error = "Incorrect MPIN";
        _pin = "";
        isAutoLoggingIn = false;
      });
    }
  }

  Future<void> _handleForgotMpin() async {
    final option = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Forgot MPIN?"),
        content: const Text("How would you like to reset your MPIN?"),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop('email'),
                child: const Text("Send Reset Code to Email"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop('password'),
                child: const Text("Sign in with Password"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
            ],
          )
        ],
      ),
    );

    if (option == 'password' && mounted) {
      await MpinStore.clearMpin();
      await CredentialStore.clearCredentials();
      setState(() {
        isMpinMode = false;
        isResettingMpin = true;
        _pin = "";
        empCodeCtrl.clear();
        passwordCtrl.clear();
      });
    } else if (option == 'email' && mounted) {
      Navigator.of(context).pushNamed(AppRoutes.mpinOtpRequest);
    }
  }

  @override
  void dispose() {
    vendorCodeCtrl.dispose();
    empCodeCtrl.dispose();
    passwordCtrl.dispose();
    serverUrlCtrl.dispose();
    super.dispose();
  }

  bool get _needsServerConfig {
    final msg = (error ?? "").toLowerCase();
    return msg.contains("set server ip") || msg.contains("api base url");
  }

  Future<void> saveServer() async {
    try {
      await setStoredApiBaseUrl(serverUrlCtrl.text);
      if (!mounted) return;
      setState(() {
        error = null;
      });
      submit();
    } catch (e) {
      if (mounted) {
        setState(() {
          final appError = ErrorHandler.handle(e);
          error = appError.userMessage;
        });
      }
    }
  }

  void submit() {
    setState(() {
      error = null;
    });

    final vendor = vendorCodeCtrl.text.trim();
    final emp = empCodeCtrl.text.trim();
    final normalizedEmp = emp.toUpperCase();
    final pass = passwordCtrl.text.trim();
    if (vendor.isEmpty || normalizedEmp.isEmpty || pass.isEmpty) {
      setState(() {
        error = "Enter Vendor Code, Emp Code and Password";
      });
      return;
    }

    if (empCodeCtrl.text != normalizedEmp) {
      empCodeCtrl.value = empCodeCtrl.value.copyWith(
        text: normalizedEmp,
        selection: TextSelection.collapsed(offset: normalizedEmp.length),
      );
    }

    context.read<AuthBloc>().add(LoginRequested(
      vendorCode: vendor,
      empCode: normalizedEmp,
      password: pass,
      rememberMe: rememberMe,
    ));
  }

  InputDecoration _buildInputDecoration(
      BuildContext context, String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Dynamically calculate logo size (e.g. 35% of screen width), constrained between 100 and 160
    final logoSize =
    (MediaQuery.sizeOf(context).width * 0.35).clamp(100.0, 160.0);

    return BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthError) {
            setState(() {
              error = state.message;
            });
          } else if (state is AuthSuccess) {
            final session = state.session;
            if (session.mustChangePassword) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(
                        session: session,
                        currentPassword: passwordCtrl.text.trim())),
              );
            } else {
              if (session.acceptedTerms) {
                await TermsStore.setAccepted(true);
              }
              final accepted = await TermsStore.isAccepted();
              final hasMpinLocal = await MpinStore.hasMpin();
              if (!context.mounted) return;
              if (!accepted) {
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.terms,
                  arguments: {
                    'isServerMpinSet': session.hasMpin,
                    'isResetMode': isResettingMpin
                  },
                );
              } else if (!hasMpinLocal) {
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.mpinSetup,
                  arguments: {
                    'isServerMpinSet': session.hasMpin,
                    'isResetMode': isResettingMpin
                  },
                );
              } else {
                Navigator.of(context).pushReplacementNamed(AppRoutes.app);
              }
            }
          }
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_currentStep > 0) {
              _previousStep();
              return;
            }
            final bool shouldPop = await showExitConfirmationDialog(context);
            if (shouldPop) {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [
                // Soft Gradient Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.surface,
                          cs.primaryContainer.withValues(alpha: 0.3),
                          cs.surface,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Decorative Abstract Shapes
                Positioned(
                  top: -100,
                  right: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -100,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.tertiary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Card(
                          elevation: 0,
                          color: cs.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 20),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (isLoadingInitialState)
                                    const SizedBox(
                                      height: 300,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else ...[
                                    // Logo and Branding
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Hero(
                                          tag: "logo",
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: _currentStep == 1 &&
                                                    vendorLogoUrl != null
                                                    ? Colors.white
                                                    : cs.primary,
                                                borderRadius:
                                                BorderRadius.circular(16),
                                              ),
                                              child: _currentStep == 1 &&
                                                  vendorLogoUrl != null
                                                  ? ClipRRect(
                                                borderRadius:
                                                BorderRadius.circular(
                                                    12),
                                                child: Image.network(
                                                  vendorLogoUrl!,
                                                  width: logoSize,
                                                  height: logoSize,
                                                  fit: BoxFit
                                                      .contain, // Safely bounds any aspect ratio dynamically
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                      Icon(
                                                        Icons
                                                            .business_center_rounded,
                                                        color: cs.onPrimary,
                                                        size: logoSize,
                                                      ),
                                                ),
                                              )
                                                  : Icon(
                                                Icons
                                                    .business_center_rounded,
                                                color: cs.onPrimary,
                                                size: logoSize,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!isMpinMode && _currentStep == 0) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        "SitePulse",
                                        textAlign: TextAlign.center,
                                        style:
                                        textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: cs.primary,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    AnimatedSwitcher(
                                      duration:
                                      const Duration(milliseconds: 300),
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.05, 0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _currentStep == 0
                                          ? _buildStep1(context, cs, textTheme)
                                          : _buildStep2(context, cs, textTheme),
                                    ),
                                    // Server Config Fallback
                                    if (_needsServerConfig) ...[
                                      const SizedBox(height: 32),
                                      Divider(color: cs.outlineVariant),
                                      const SizedBox(height: 32),
                                      TextField(
                                        controller: serverUrlCtrl,
                                        textInputAction: TextInputAction.done,
                                        clipBehavior: Clip.none,
                                        decoration: _buildInputDecoration(
                                          context,
                                          "Server URL",
                                          "Enter API URL",
                                          Icons.public,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      BlocBuilder<AuthBloc, AuthState>(
                                        builder: (context, state) {
                                          final isSubmitting =
                                          state is AuthLoading;
                                          return SizedBox(
                                            height: 56,
                                            width: double.infinity,
                                            child: FilledButton.tonal(
                                              style: FilledButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(18),
                                                ),
                                              ),
                                              onPressed: isSubmitting
                                                  ? null
                                                  : saveServer,
                                              child: Text(
                                                "Save Server",
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildStep1(
      BuildContext context, ColorScheme cs, TextTheme textTheme) {
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Enter your Vendor Code to connect to your workspace",
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: vendorCodeCtrl,
          textInputAction: TextInputAction.done,
          clipBehavior: Clip.none,
          onSubmitted: (_) => _nextStep(),
          decoration: _buildInputDecoration(
            context,
            "Vendor Code",
            "Enter vendor code",
            Icons.domain_outlined,
          ),
        ),
        const SizedBox(height: 32),
        if (error != null) _buildError(cs, textTheme),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: isFetchingBranding ? null : _nextStep,
            child: isFetchingBranding
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
                : Text(
              "Next",
              style: textTheme.titleMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(
      BuildContext context, ColorScheme cs, TextTheme textTheme) {
    if (isMpinMode) {
      return Column(
        key: const ValueKey("mpin"),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Welcome back,",
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [cs.primary, cs.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              _engineerName,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isAutoLoggingIn)
            const Center(child: CircularProgressIndicator())
          else
            Center(
              child: Pinput(
                length: 4,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onCompleted: (pin) {
                  setState(() => _pin = pin);
                  _verifyMpinAndLogin();
                },
                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 64,
                  textStyle: textTheme.headlineMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 64,
                  textStyle: textTheme.headlineMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                errorPinTheme: PinTheme(
                  width: 56,
                  height: 64,
                  textStyle: textTheme.headlineMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.error,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isAutoLoggingIn ? null : _handleForgotMpin,
            child: Text(
              "Forgot MPIN?",
              style: textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: empCodeCtrl,
          textInputAction: TextInputAction.next,
          clipBehavior: Clip.none,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9\-_/]")),
            UpperCaseTextFormatter(),
          ],
          decoration: _buildInputDecoration(
            context,
            "Employee Code",
            "Enter your code",
            Icons.badge_outlined,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordCtrl,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          clipBehavior: Clip.none,
          onSubmitted: (_) => submit(),
          decoration: _buildInputDecoration(
            context,
            "Password",
            "••••••••",
            Icons.lock_outline,
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isSubmitting = state is AuthLoading;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: isSubmitting
                            ? null
                            : (v) => setState(() => rememberMe = v ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Remember me",
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Forgot Password?"),
                        content: const Text(
                            "For security reasons, field engineers cannot reset passwords directly from the app. Please contact your Vendor Administrator or Manager to issue a new password for your account."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Okay"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    "Forgot Password?",
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        if (error != null) _buildError(cs, textTheme),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isSubmitting = state is AuthLoading;
            return SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
                    : Text(
                  "Log In",
                  style: textTheme.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isSubmitting = state is AuthLoading;
            return TextButton(
              onPressed: isSubmitting ? null : _previousStep,
              child: Text(
                "Change Workspace",
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme cs, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class ChangePasswordScreen extends StatelessWidget {
  final AuthSessionModel session;
  final String currentPassword;

  const ChangePasswordScreen(
      {super.key, required this.session, required this.currentPassword});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: ChangePasswordScreenView(
          session: session, currentPassword: currentPassword),
    );
  }
}

class ChangePasswordScreenView extends StatefulWidget {
  final AuthSessionModel session;
  final String currentPassword;

  const ChangePasswordScreenView(
      {super.key, required this.session, required this.currentPassword});

  @override
  State<ChangePasswordScreenView> createState() =>
      _ChangePasswordScreenViewState();
}

class _ChangePasswordScreenViewState extends State<ChangePasswordScreenView> {
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  String? error;

  @override
  void dispose() {
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  bool _looksStrong(String s) {
    if (s.length < 8 || s.length > 128) return false;
    final hasLetter = s.split("").any((ch) => RegExp(r"[A-Za-z]").hasMatch(ch));
    final hasDigit = s.split("").any((ch) => RegExp(r"[0-9]").hasMatch(ch));
    return hasLetter && hasDigit;
  }

  void submit() {
    setState(() {
      error = null;
    });

    final newPw = newPasswordCtrl.text.trim();
    final confirmPw = confirmPasswordCtrl.text.trim();
    if (newPw.isEmpty || confirmPw.isEmpty) {
      setState(() {
        error = "Enter and confirm your new password";
      });
      return;
    }
    if (newPw != confirmPw) {
      setState(() {
        error = "Passwords do not match";
      });
      return;
    }
    if (!_looksStrong(newPw)) {
      setState(() {
        error = "Password must be 8-128 chars and include letters and numbers";
      });
      return;
    }

    final emp = widget.session.engineer.empCode.trim();
    final mobile = widget.session.engineer.mobileNo.trim();
    if (emp.isNotEmpty && newPw.toLowerCase() == emp.toLowerCase()) {
      setState(() {
        error = "New password cannot be the same as Emp Code";
      });
      return;
    }
    if (mobile.isNotEmpty && newPw == mobile) {
      setState(() {
        error = "New password cannot be the same as Mobile No";
      });
      return;
    }

    context.read<AuthBloc>().add(ChangePasswordRequested(
      token: widget.session.token,
      currentPassword: widget.currentPassword,
      newPassword: newPw,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engineer = widget.session.engineer;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthError) {
          setState(() {
            error = state.message;
          });
        } else if (state is AuthInitial) {
          // Success case for ChangePassword
          if (widget.session.acceptedTerms) {
            await TermsStore.setAccepted(true);
          }
          final accepted = await TermsStore.isAccepted();
          if (!context.mounted) return;
          Navigator.of(context)
              .pushReplacementNamed(accepted ? AppRoutes.app : AppRoutes.terms);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Change Password")),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.lock_outline, color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Update your password",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  "Hi ${engineer.fullName}. For security, you must set a new password before continuing.",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                if (error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .extension<AppColorsExtension>()!
                          .errorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withAlpha(40)),
                    ),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 14),
                ],
                AppTextField(
                  label: "New Password",
                  controller: newPasswordCtrl,
                  hint: "Enter new password",
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  helperText:
                  "8 to 10 characters, at least 1 letter and 1 number.",
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: "Confirm New Password",
                  controller: confirmPasswordCtrl,
                  hint: "Repeat password",
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(120),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withAlpha(160)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Password Requirements",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: -0.2),
                      ),
                      SizedBox(height: 8),
                      Text("Minimum 8 characters",
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text("Must include at least 1 letter",
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text("Must include at least 1 number",
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text("Cannot be the same as your Employee Code",
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text("Cannot be the same as your Mobile Number",
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isSubmitting = state is AuthLoading;
                    return PrimaryButton(
                      label: "Update Password",
                      onPressed: isSubmitting ? null : submit,
                      isLoading: isSubmitting,
                      icon: Icons.check_circle_outline,
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  "Tip: Use a password you don’t use elsewhere.",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
      composing: TextRange.empty,
    );
  }
}
