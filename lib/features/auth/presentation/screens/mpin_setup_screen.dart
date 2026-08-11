import "package:flutter/material.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/storage/mpin_store.dart";
import 'package:pinput/pinput.dart';
import 'package:sitepulse_engineer/features/auth/data/services/auth_service.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class MpinSetupScreen extends StatefulWidget {
  final bool isServerMpinSet;
  final bool isResetMode;
  const MpinSetupScreen({
    super.key,
    this.isServerMpinSet = false,
    this.isResetMode = false,
  });

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

    if (_isServerMpinSet) {
      _verifyAgainstServer(pin);
      return;
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

  Future<void> _verifyAgainstServer(String pin) async {
    setState(() => _errorMessage = "");
    try {
      final session = SessionStore.current;
      if (session != null) {
        await AuthService().verifyMpin(session.token, pin);
        await MpinStore.setMpin(pin);
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.app, (route) => false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Invalid MPIN. Try again.";
        _pin = "";
        _pinController.clear();
      });
    }
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      try {
        final session = SessionStore.current;
        if (session != null) {
          await AuthService().setMpin(session.token, _pin);
        }
        await MpinStore.setMpin(_pin);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.app, (route) => false);
        }
      } catch (e) {
        setState(() {
          _errorMessage = "Failed to save MPIN to server.";
          _pin = "";
          _confirmPin = "";
          _isConfirming = false;
          _pinController.clear();
        });
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

  bool get _isServerMpinSet {
    if (widget.isResetMode) return false;
    if (widget.isServerMpinSet) return true;
    return SessionStore.current?.hasMpin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isServerMpinSet ? "Enter Existing MPIN" : (_isConfirming ? "Confirm MPIN" : "Set MPIN");
    final subtitle = _isServerMpinSet
        ? "Enter the MPIN you created previously"
        : (_isConfirming
            ? "Re-enter your 4-digit MPIN"
            : "Create a 4-digit MPIN for quick access");
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
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
