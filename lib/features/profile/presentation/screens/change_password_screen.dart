import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/features/profile/presentation/bloc/change_password_bloc.dart";

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, required this.sessionToken});

  final String sessionToken;

  static Future<void> show(BuildContext context, {required String sessionToken}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.70,
      ),
      builder: (_) => BlocProvider(
        create: (_) => ChangePasswordBloc(),
        child: _ChangePasswordView(sessionToken: sessionToken, isSheet: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChangePasswordBloc(),
      child: _ChangePasswordView(sessionToken: sessionToken),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  final String sessionToken;
  final bool isSheet;

  const _ChangePasswordView({required this.sessionToken, this.isSheet = false});

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChangePasswordBloc, ChangePasswordState>(
      listener: (context, state) {
        if (state is ChangePasswordSuccess) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Password updated")));
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: widget.isSheet ? null : AppBar(title: const Text("Change Password")),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              widget.isSheet ? 8 : 18,
              18,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ListView(
              children: [
                if (widget.isSheet) ...[
                  Text("Change Password", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Choose a strong new password for your account.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: BlocBuilder<ChangePasswordBloc, ChangePasswordState>(
                        builder: (context, state) {
                      final isSubmitting = state is ChangePasswordSubmitting;
                      final error =
                          state is ChangePasswordError ? state.message : null;

                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          _passwordField(
                            label: "Current password",
                            controller: currentCtrl,
                            action: TextInputAction.next,
                            obscureText: _obscureCurrent,
                            onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),
                          const SizedBox(height: 12),
                          _passwordField(
                            label: "New password",
                            controller: newCtrl,
                            action: TextInputAction.next,
                            minLength: true,
                            obscureText: _obscureNew,
                            onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          const SizedBox(height: 12),
                          _passwordField(
                            label: "Confirm new password",
                            controller: confirmCtrl,
                            action: TextInputAction.done,
                            confirm: true,
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(error,
                                style: const TextStyle(
                                    color: Color(0xFF9F1239),
                                    fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                                child: const Text("Cancel"),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: isSubmitting ? null : () {
                                  if (!(_formKey.currentState?.validate() ?? false)) return;
                                  context.read<ChangePasswordBloc>().add(ChangePasswordSubmitted(
                                    sessionToken: widget.sessionToken,
                                    currentPassword: currentCtrl.text.trim(),
                                    newPassword: newCtrl.text.trim(),
                                    confirmPassword: confirmCtrl.text.trim(),
                                  ));
                                },
                                child: isSubmitting
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text("Submit"),
                              ),
                            ],
                          ),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required TextInputAction action,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    bool minLength = false,
    bool confirm = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: action,
      validator: (value) {
        final text = (value ?? "").trim();
        if (text.isEmpty) return "Please enter $label";
        if (minLength && text.length < 8) return "Password must be at least 8 characters";
        if (confirm && text != newCtrl.text) return "Passwords do not match";
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: colors.onSurfaceVariant,
          ),
          tooltip: obscureText ? "Show $label" : "Hide $label",
        ),
      ),
    );
  }
}
