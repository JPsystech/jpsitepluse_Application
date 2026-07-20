import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

import "package:sitepulse_engineer/core/config/api_config.dart";
import "package:sitepulse_engineer/core/storage/terms_store.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/shared/widgets/app_text_field.dart";
import "package:sitepulse_engineer/shared/widgets/primary_button.dart";

import "package:sitepulse_engineer/features/auth/data/models/auth_session_model.dart";
import "package:sitepulse_engineer/features/auth/presentation/bloc/auth_bloc.dart";

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

  @override
  void initState() {
    super.initState();
    serverUrlCtrl.text = productionApiBaseUrl;
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
          error = e.toString();
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
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
            final accepted = await TermsStore.isAccepted();
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(
                accepted ? AppRoutes.mpinSetup : AppRoutes.terms);
          }
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
                      cs.primaryContainer.withOpacity(0.3),
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
                  color: cs.primary.withOpacity(0.05),
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
                  color: cs.tertiary.withOpacity(0.05),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo and Branding
                            Hero(
                              tag: "logo",
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.business_center_rounded,
                                    color: cs.onPrimary,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "SitePulse",
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              "Welcome Back",
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sign in to continue to your workspace",
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Login Form
                            TextField(
                              controller: vendorCodeCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: _buildInputDecoration(
                                context,
                                "Vendor Code",
                                "Enter vendor code",
                                Icons.domain_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: empCodeCtrl,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r"[A-Za-z0-9\-_/]")),
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
                              onSubmitted: (_) => submit(),
                              decoration: _buildInputDecoration(
                                context,
                                "Password",
                                "••••••••",
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                      () => obscurePassword = !obscurePassword),
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
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: rememberMe,
                                        onChanged: isSubmitting
                                            ? null
                                            : (v) => setState(
                                                () => rememberMe = v ?? false),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            // Error State
                            if (error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cs.error.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: cs.error, size: 20),
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
                            // Submit Button
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
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                              color: cs.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                            // Server Config Fallback
                            if (_needsServerConfig) ...[
                              const SizedBox(height: 32),
                              Divider(color: cs.outlineVariant),
                              const SizedBox(height: 32),
                              TextField(
                                controller: serverUrlCtrl,
                                textInputAction: TextInputAction.done,
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
                                  final isSubmitting = state is AuthLoading;
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
                                      onPressed:
                                          isSubmitting ? null : saveServer,
                                      child: Text(
                                        "Save Server",
                                        style:
                                            textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          final accepted = await TermsStore.isAccepted();
          if (!mounted) return;
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
