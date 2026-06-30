import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/shared/widgets/app_text_field.dart";
import "package:sitepulse_engineer/shared/widgets/primary_button.dart";
import "package:sitepulse_engineer/features/profile/presentation/bloc/change_password_bloc.dart";

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, required this.sessionToken});

  final String sessionToken;

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

  const _ChangePasswordView({required this.sessionToken});

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

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
        appBar: AppBar(title: const Text("Change Password")),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: BlocBuilder<ChangePasswordBloc, ChangePasswordState>(
                        builder: (context, state) {
                      final isSubmitting = state is ChangePasswordSubmitting;
                      final error =
                          state is ChangePasswordError ? state.message : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Update your password",
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2)),
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
                            Text(error,
                                style: const TextStyle(
                                    color: Color(0xFF9F1239),
                                    fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 16),
                          PrimaryButton(
                              label: "Save",
                              onPressed: isSubmitting
                                  ? null
                                  : () => context
                                      .read<ChangePasswordBloc>()
                                      .add(ChangePasswordSubmitted(
                                        sessionToken: widget.sessionToken,
                                        currentPassword:
                                            currentCtrl.text.trim(),
                                        newPassword: newCtrl.text.trim(),
                                        confirmPassword:
                                            confirmCtrl.text.trim(),
                                      )),
                              isLoading: isSubmitting,
                              icon: Icons.lock_reset),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
