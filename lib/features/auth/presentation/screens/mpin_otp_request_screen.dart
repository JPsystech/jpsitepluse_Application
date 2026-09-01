import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sitepulse_engineer/core/storage/credential_store.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';

class MpinOtpRequestScreen extends StatelessWidget {
  const MpinOtpRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: const _MpinOtpRequestScreenView(),
    );
  }
}

class _MpinOtpRequestScreenView extends StatefulWidget {
  const _MpinOtpRequestScreenView();

  @override
  State<_MpinOtpRequestScreenView> createState() => _MpinOtpRequestScreenViewState();
}

class _MpinOtpRequestScreenViewState extends State<_MpinOtpRequestScreenView> {
  final _emailCtrl = TextEditingController();
  String? _error;
  bool _isLoading = false;

  void _handleSubmit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = "Please enter your registered email";
      });
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final creds = await CredentialStore.getCredentials();
      if (creds == null) {
        throw Exception("No credentials found. Please log in again.");
      }

      final vendorCode = creds['vendorCode']!;
      final empCode = creds['empCode']!;

      context.read<AuthBloc>().add(
            SendMpinOtpEvent(
              vendorCode: vendorCode,
              empCode: empCode,
              email: email,
            ),
          );
    } catch (e) {
      setState(() {
        final appError = ErrorHandler.handle(e);
        _error = appError.userMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() {
            _isLoading = false;
            _error = state.message;
          });
        } else if (state is AuthMpinOtpSent) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pushNamed(
            AppRoutes.mpinOtpVerify,
            arguments: {
              'vendorCode': state.vendorCode,
              'empCode': state.empCode,
            },
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reset MPIN"),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.email_outlined, size: 64, color: cs.primary),
                const SizedBox(height: 24),
                Text(
                  "Verify your email",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Enter the email address associated with your account to receive a 4-digit reset code.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: const Icon(Icons.email),
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Send Reset Code", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
