import "package:flutter/material.dart";

import "../../services/auth_service.dart";
import "../../widgets/app_text_field.dart";
import "../../widgets/primary_button.dart";

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.sessionToken});

  final String sessionToken;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool isSubmitting = false;
  String? error;

  @override
  void dispose() {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  bool _looksStrong(String s) {
    if (s.length < 8 || s.length > 128) return false;
    final hasLetter = s.split("").any((ch) => RegExp(r"[A-Za-z]").hasMatch(ch));
    final hasDigit = s.split("").any((ch) => RegExp(r"[0-9]").hasMatch(ch));
    return hasLetter && hasDigit;
  }

  Future<void> submit() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
      error = null;
    });

    try {
      final currentPw = currentCtrl.text.trim();
      final nextPw = newCtrl.text.trim();
      final confirmPw = confirmCtrl.text.trim();

      if (currentPw.isEmpty || nextPw.isEmpty || confirmPw.isEmpty) {
        throw "All fields are required";
      }
      if (nextPw != confirmPw) {
        throw "Passwords do not match";
      }
      if (!_looksStrong(nextPw)) {
        throw "Password must be 8-128 chars and include letters and numbers";
      }

      await AuthService().changePassword(token: widget.sessionToken, currentPassword: currentPw, newPassword: nextPw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated")));
      Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text("Change Password")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Update your password", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: "Current password",
                        controller: currentCtrl,
                        obscureText: true,
                        showLabel: false,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: "New password",
                        controller: newCtrl,
                        obscureText: true,
                        showLabel: false,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: "Confirm new password",
                        controller: confirmCtrl,
                        obscureText: true,
                        showLabel: false,
                        textInputAction: TextInputAction.done,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 16),
                      PrimaryButton(label: "Save", onPressed: isSubmitting ? null : submit, isLoading: isSubmitting, icon: Icons.lock_reset),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

