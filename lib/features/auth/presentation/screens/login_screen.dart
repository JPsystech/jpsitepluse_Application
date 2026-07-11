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
  final companyCodeCtrl = TextEditingController();
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
    companyCodeCtrl.dispose();
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

    final company = companyCodeCtrl.text.trim();
    final emp = empCodeCtrl.text.trim();
    final normalizedEmp = emp.toUpperCase();
    final pass = passwordCtrl.text.trim();
    if (company.isEmpty || normalizedEmp.isEmpty || pass.isEmpty) {
      setState(() {
        error = "Enter Company Code, Emp Code and Password";
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
          companyCode: company,
          empCode: normalizedEmp,
          password: pass,
        ));
  }


  @override
  Widget build(BuildContext context) {
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
                accepted ? AppRoutes.app : AppRoutes.terms);
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Premium Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary.withAlpha(20),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
            // Decorative Elements
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withAlpha(12),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withAlpha(10),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Hero(
                          tag: "logo",
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    const Color(0xFF0EA5E9)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(40),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                child: const Icon(Icons.engineering_rounded,
                                    color: Colors.white, size: 40),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "Welcome Back",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Log in to your engineer account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: Theme.of(context)
                                .extension<AppColorsExtension>()!
                                .softShadow,
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withAlpha(8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppTextField(
                                label: "Company Code",
                                controller: companyCodeCtrl,
                                prefixIcon: Icons.domain_outlined,
                                hint: "Enter company code",
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 20),
                              AppTextField(
                                label: "Employee Code",
                                controller: empCodeCtrl,
                                prefixIcon: Icons.badge_outlined,
                                hint: "Enter your code",
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r"[A-Za-z0-9\-_/]")),
                                  UpperCaseTextFormatter(),
                                ],
                                helperText:
                                    "Employee code is entered in uppercase.",
                              ),
                              const SizedBox(height: 20),
                              AppTextField(
                                label: "Password",
                                controller: passwordCtrl,
                                obscureText: obscurePassword,
                                prefixIcon: Icons.lock_outline,
                                hint: "••••••••",
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                      () => obscurePassword = !obscurePassword),
                                  icon: Icon(obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                ),
                                onSubmitted: (_) => submit(),
                              ),
                              const SizedBox(height: 8),
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isSubmitting = state is AuthLoading;
                                  return CheckboxListTile(
                                    value: rememberMe,
                                    onChanged: isSubmitting
                                        ? null
                                        : (v) => setState(
                                            () => rememberMe = v ?? false),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: const Text(
                                      "Remember me",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              if (error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .extension<AppColorsExtension>()!
                                        .errorBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error
                                            .withAlpha(30)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isSubmitting = state is AuthLoading;
                                  return PrimaryButton(
                                    label: "Log In",
                                    onPressed: isSubmitting ? null : submit,
                                    isLoading: isSubmitting,
                                    icon: Icons.login_rounded,
                                  );
                                },
                              ),
                              if (_needsServerConfig) ...[
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: "Server URL",
                                  controller: serverUrlCtrl,
                                  showLabel: false,
                                  prefixIcon: Icons.public,
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: 10),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final isSubmitting = state is AuthLoading;
                                    return PrimaryButton(
                                      label: "Save Server",
                                      onPressed:
                                          isSubmitting ? null : saveServer,
                                      isLoading: false,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "Forgot password?\nContact your administrator to reset it.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.5),
                        ),
                      ],
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
