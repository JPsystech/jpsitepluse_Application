import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sitepulse_engineer/features/profile/presentation/bloc/change_password_bloc.dart";
import "package:sitepulse_engineer/shared/widgets/app_form_fields.dart";

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, required this.sessionToken});
  final String sessionToken;

  static Future<void> show(BuildContext context, {required String sessionToken}) => showModalBottomSheet<void>(
        context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true,
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .94),
        builder: (_) => BlocProvider(create: (_) => ChangePasswordBloc(), child: _ChangePasswordView(sessionToken: sessionToken, isSheet: true)),
      );

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => ChangePasswordBloc(), child: _ChangePasswordView(sessionToken: sessionToken));
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView({required this.sessionToken, this.isSheet = false});
  final String sessionToken;
  final bool isSheet;
  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool _obscureCurrent = true, _obscureNew = true, _obscureConfirm = true;

  @override
  void dispose() { currentCtrl.dispose(); newCtrl.dispose(); confirmCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !widget.isSheet,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, widget.isSheet ? 8 : 18, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: BlocBuilder<ChangePasswordBloc, ChangePasswordState>(
          builder: (context, state) {
            final submitting = state is ChangePasswordSubmitting;
            final error = state is ChangePasswordError ? state.message : null;
            return Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.isSheet) ...[
                  Text("Change Password", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Choose a strong new password for your account.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                ],
                _field("Current password", currentCtrl, TextInputAction.next, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
                const SizedBox(height: 12),
                _field("New password", newCtrl, TextInputAction.next, _obscureNew, () => setState(() => _obscureNew = !_obscureNew), minLength: true),
                const SizedBox(height: 12),
                _field("Confirm new password", confirmCtrl, TextInputAction.done, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm), confirm: true),
                if (error != null) ...[const SizedBox(height: 12), Text(error, style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700))],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(), child: const Text("Cancel")),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: submitting ? null : _submit, child: submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Submit")),
                ]),
              ]),
            );
          },
        ),
      ),
    );
    return BlocListener<ChangePasswordBloc, ChangePasswordState>(
      listener: (context, state) {
        if (state is ChangePasswordSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated")));
          Navigator.of(context).pop();
        }
      },
      child: widget.isSheet ? Material(color: Theme.of(context).colorScheme.surface, child: content) : Scaffold(appBar: AppBar(title: const Text("Change Password")), body: content),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<ChangePasswordBloc>().add(ChangePasswordSubmitted(sessionToken: widget.sessionToken, currentPassword: currentCtrl.text.trim(), newPassword: newCtrl.text.trim(), confirmPassword: confirmCtrl.text.trim()));
  }

  Widget _field(String label, TextEditingController controller, TextInputAction action, bool obscure, VoidCallback toggle, {bool minLength = false, bool confirm = false}) => AppTextFormField(
        controller: controller, obscureText: obscure, textInputAction: action, label: label,
        validator: (value) {
          final text = (value ?? "").trim();
          if (text.isEmpty) return "Please enter $label";
          if (minLength && text.length < 8) return "Password must be at least 8 characters";
          if (confirm && text != newCtrl.text) return "Passwords do not match";
          return null;
        },
        suffixIcon: IconButton(onPressed: toggle, icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
      );
}
