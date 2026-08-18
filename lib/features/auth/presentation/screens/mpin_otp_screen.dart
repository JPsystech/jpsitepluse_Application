import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import 'package:sitepulse_engineer/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sitepulse_engineer/core/router/app_routes.dart';

class MpinOtpScreen extends StatelessWidget {
  final String vendorCode;
  final String empCode;

  const MpinOtpScreen({
    super.key,
    required this.vendorCode,
    required this.empCode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: _MpinOtpScreenView(vendorCode: vendorCode, empCode: empCode),
    );
  }
}

class _MpinOtpScreenView extends StatefulWidget {
  final String vendorCode;
  final String empCode;

  const _MpinOtpScreenView({
    required this.vendorCode,
    required this.empCode,
  });

  @override
  State<_MpinOtpScreenView> createState() => _MpinOtpScreenViewState();
}

class _MpinOtpScreenViewState extends State<_MpinOtpScreenView> {
  final _pinCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  bool _isLoading = false;

  Timer? _timer;
  int _secondsRemaining = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 300;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _verifyOtp(String pin) {
    if (pin.length != 4) return;
    
    setState(() {
      _error = null;
      _isLoading = true;
    });

    context.read<AuthBloc>().add(
          VerifyMpinOtpEvent(
            vendorCode: widget.vendorCode,
            empCode: widget.empCode,
            otp: pin,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: cs.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: cs.error, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final minutes = (_secondsRemaining / 60).floor();
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() {
            _isLoading = false;
            _error = state.message;
            _pinCtrl.clear();
            _focusNode.requestFocus();
          });
        } else if (state is AuthMpinOtpVerified) {
          setState(() {
            _isLoading = false;
          });
          // Go to MpinSetupScreen, passing the reset token so it can set the new MPIN
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.mpinSetup,
            arguments: {
              'resetToken': state.resetToken,
              'isResetMode': true,
              'isServerMpinSet': false,
            },
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Verify Reset Code"),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_reset, size: 64, color: cs.primary),
                const SizedBox(height: 24),
                Text(
                  "Enter 4-Digit Code",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "We have sent a reset code to your registered email address.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Center(
                  child: Pinput(
                    length: 4,
                    controller: _pinCtrl,
                    focusNode: _focusNode,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    errorPinTheme: errorPinTheme,
                    forceErrorState: _error != null,
                    showCursor: true,
                    onCompleted: _isLoading ? null : _verifyOtp,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    readOnly: _isLoading,
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _error!,
                      style: TextStyle(color: cs.error, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: [
                      Text(
                        "Code expires in $minutes:$seconds",
                        style: TextStyle(
                          color: _secondsRemaining < 60 ? cs.error : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _secondsRemaining == 0
                            ? () {
                                Navigator.of(context).pop(); // Go back to request screen
                              }
                            : null,
                        child: Text(
                          "Resend Code",
                          style: TextStyle(
                            color: _secondsRemaining == 0 ? cs.primary : cs.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
