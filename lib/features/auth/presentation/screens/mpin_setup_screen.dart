import "package:flutter/material.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/storage/mpin_store.dart";
import 'package:pinput/pinput.dart';

class MpinSetupScreen extends StatefulWidget {
  const MpinSetupScreen({super.key});

  @override
  State<MpinSetupScreen> createState() => _MpinSetupScreenState();
}

class _MpinSetupScreenState extends State<MpinSetupScreen> {
  String _pin = "";
  String _confirmPin = "";
  bool _isConfirming = false;
  String _errorMessage = "";

  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onPinCompleted(String pin) {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = "");
    }

    if (!_isConfirming) {
      setState(() {
        _pin = pin;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isConfirming = true;
            _pinController.clear();
          });
        }
      });
    } else {
      setState(() {
        _confirmPin = pin;
      });
      _verifyAndSave();
    }
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      await MpinStore.setMpin(_pin);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.app, (route) => false);
      }
    } else {
      setState(() {
        _errorMessage = "MPINs do not match. Try again.";
        _pin = "";
        _confirmPin = "";
        _isConfirming = false;
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isConfirming ? "Confirm MPIN" : "Set MPIN";
    final subtitle = _isConfirming
        ? "Re-enter your 4-digit MPIN"
        : "Create a 4-digit MPIN for quick access";
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 60),
            Center(
              child: Pinput(
                key: ValueKey(_isConfirming ? "confirm" : "set"),
                controller: _pinController,
                length: 4,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                onCompleted: _onPinCompleted,
                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 64,
                  textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 64,
                  textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                errorPinTheme: PinTheme(
                  width: 56,
                  height: 64,
                  textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const Spacer(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
