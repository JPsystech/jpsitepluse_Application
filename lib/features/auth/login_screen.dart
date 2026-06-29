import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../../theme/app_theme.dart";

import "../../core/api_config.dart";
import "../../core/session_store.dart";
import "../../core/terms_store.dart";
import "../../models/auth_session.dart";
import "../../routes/app_routes.dart";
import "../../services/auth_service.dart";
import "../../widgets/app_text_field.dart";
import "../../widgets/primary_button.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final empCodeCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final serverUrlCtrl = TextEditingController();

  bool isSubmitting = false;
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
      await submit();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    }
  }

  Future<void> submit() async {
    setState(() {
      isSubmitting = true;
      error = null;
    });

    try {
      final emp = empCodeCtrl.text.trim();
      final normalizedEmp = emp.toUpperCase();
      final pass = passwordCtrl.text.trim();
      if (normalizedEmp.isEmpty || pass.isEmpty) {
        setState(() {
          error = "Enter Emp Code and Password";
        });
        return;
      }

      if (empCodeCtrl.text != normalizedEmp) {
        empCodeCtrl.value = empCodeCtrl.value.copyWith(
          text: normalizedEmp,
          selection: TextSelection.collapsed(offset: normalizedEmp.length),
        );
      }

      final session = await AuthService().login(empCode: normalizedEmp, password: pass, rememberMe: rememberMe);
      await SessionStore.set(session);
      if (!mounted) return;
      if (session.mustChangePassword) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChangePasswordScreen(session: session, currentPassword: pass)),
        );
      } else {
        final accepted = await TermsStore.isAccepted();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(accepted ? AppRoutes.app : AppRoutes.terms);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  AppTheme.sky.withAlpha(20),
                  AppTheme.bg,
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
                color: AppTheme.sky.withAlpha(12),
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
                color: AppTheme.sky.withAlpha(10),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                              gradient: const LinearGradient(
                                colors: [AppTheme.sky, Color(0xFF0EA5E9)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.sky.withAlpha(40),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.navy,
                              ),
                              child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Welcome Back",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2, color: AppTheme.navy),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Log in to your engineer account",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: AppTheme.softShadow,
                          border: Border.all(color: AppTheme.navy.withAlpha(8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: "Employee Code",
                              controller: empCodeCtrl,
                              prefixIcon: Icons.badge_outlined,
                              hint: "Enter your code",
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9\-_/]")),
                                UpperCaseTextFormatter(),
                              ],
                              helperText: "Employee code is entered in uppercase.",
                            ),
                            const SizedBox(height: 20),
                            AppTextField(
                              label: "Password",
                              controller: passwordCtrl,
                              obscureText: obscurePassword,
                              prefixIcon: Icons.lock_outline,
                              hint: "••••••••",
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                              onSubmitted: (_) => submit(),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: rememberMe,
                              onChanged: isSubmitting ? null : (v) => setState(() => rememberMe = v ?? false),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                "Remember me",
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.dangerBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.danger.withAlpha(30)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        error!,
                                        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            PrimaryButton(
                              label: "Log In",
                              onPressed: isSubmitting ? null : submit,
                              isLoading: isSubmitting,
                              icon: Icons.login_rounded,
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
                              PrimaryButton(
                                label: "Save Server",
                                onPressed: isSubmitting ? null : saveServer,
                                isLoading: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Forgot password?\nContact your administrator to reset it.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted, fontSize: 13, fontWeight: FontWeight.w700, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  final AuthSession session;
  final String currentPassword;

  const ChangePasswordScreen({super.key, required this.session, required this.currentPassword});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool isSubmitting = false;
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

  Future<void> submit() async {
    setState(() {
      isSubmitting = true;
      error = null;
    });

    try {
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

      await AuthService().changePassword(
        token: widget.session.token,
        currentPassword: widget.currentPassword,
        newPassword: newPw,
      );
      await SessionStore.set(
        AuthSession(
          token: widget.session.token,
          engineer: widget.session.engineer,
          mustChangePassword: false,
          expiresAtMs: widget.session.expiresAtMs,
        ),
      );
      if (!mounted) return;
      final accepted = await TermsStore.isAccepted();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(accepted ? AppRoutes.app : AppRoutes.terms);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engineer = widget.session.engineer;

    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                "Hi ${engineer.fullName}. For security, you must set a new password before continuing.",
                style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.danger.withAlpha(40)),
                  ),
                  child: Text(error!, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 14),
              ],
              AppTextField(
                label: "New Password",
                controller: newPasswordCtrl,
                hint: "Enter new password",
                obscureText: true,
                textInputAction: TextInputAction.next,
                helperText: "8-128 characters, at least 1 letter and 1 number.",
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Password Requirements",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
                    ),
                    SizedBox(height: 8),
                    Text("Minimum 8 characters", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                    Text("Maximum 128 characters", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                    Text("Must include at least 1 letter", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                    Text("Must include at least 1 number", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                    Text("Cannot be the same as your Employee Code", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                    Text("Cannot be the same as your Mobile Number", style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: "Update Password",
                onPressed: isSubmitting ? null : submit,
                isLoading: isSubmitting,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 18),
              const Text(
                "Tip: Use a password you don’t use elsewhere.",
                style: TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
      composing: TextRange.empty,
    );
  }
}
