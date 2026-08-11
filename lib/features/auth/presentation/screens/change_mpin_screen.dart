import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:pinput/pinput.dart";

import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";
import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/storage/mpin_store.dart";
import "package:sitepulse_engineer/features/auth/data/services/auth_service.dart";

class ChangeMpinScreen extends StatefulWidget {
  const ChangeMpinScreen({super.key});

  @override
  State<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

enum _ChangeMpinStep { verifyCurrent, enterNew, confirmNew }

class _ChangeMpinScreenState extends State<ChangeMpinScreen> {
  _ChangeMpinStep _currentStep = _ChangeMpinStep.verifyCurrent;
  
  String _currentPin = "";
  String _newPin = "";
  String _confirmPin = "";
  String _errorMessage = "";
  bool _isLoading = false;

  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onPinCompleted(String pin) async {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = "");
    }

    switch (_currentStep) {
      case _ChangeMpinStep.verifyCurrent:
        _currentPin = pin;
        await _verifyCurrentMpin();
        break;
      case _ChangeMpinStep.enterNew:
        setState(() {
          _newPin = pin;
          _currentStep = _ChangeMpinStep.confirmNew;
        });
        _pinController.clear();
        break;
      case _ChangeMpinStep.confirmNew:
        _confirmPin = pin;
        await _saveNewMpin();
        break;
    }
  }

  Future<void> _verifyCurrentMpin() async {
    setState(() => _isLoading = true);
    try {
      final session = SessionStore.current;
      if (session != null) {
        await AuthService().verifyMpin(session.token, _currentPin);
        // Success
        setState(() {
          _currentStep = _ChangeMpinStep.enterNew;
          _isLoading = false;
        });
        _pinController.clear();
      } else {
        throw Exception("No session");
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Incorrect current MPIN. Try again.";
        _currentPin = "";
        _isLoading = false;
        _pinController.clear();
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _saveNewMpin() async {
    if (_newPin != _confirmPin) {
      setState(() {
        _errorMessage = "MPINs do not match. Try again.";
        _confirmPin = "";
        _newPin = "";
        _currentStep = _ChangeMpinStep.enterNew;
        _pinController.clear();
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final session = SessionStore.current;
      if (session != null) {
        await AuthService().setMpin(session.token, _newPin);
        await MpinStore.setMpin(_newPin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("MPIN changed successfully")),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to save new MPIN.";
        _confirmPin = "";
        _newPin = "";
        _currentStep = _ChangeMpinStep.enterNew;
        _isLoading = false;
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String title;
    String subtitle;
    
    switch (_currentStep) {
      case _ChangeMpinStep.verifyCurrent:
        title = "Verify Current MPIN";
        subtitle = "Enter your current 4-digit MPIN to continue";
        break;
      case _ChangeMpinStep.enterNew:
        title = "Create New MPIN";
        subtitle = "Enter your new 4-digit MPIN";
        break;
      case _ChangeMpinStep.confirmNew:
        title = "Confirm New MPIN";
        subtitle = "Re-enter your new 4-digit MPIN";
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Change MPIN"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _currentStep == _ChangeMpinStep.verifyCurrent 
                      ? Icons.lock_outline 
                      : Icons.lock_reset,
                  size: 64,
                  color: cs.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Center(
                    child: Pinput(
                      controller: _pinController,
                      length: 4,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onCompleted: _onPinCompleted,
                      defaultPinTheme: PinTheme(
                        width: 64,
                        height: 64,
                        textStyle: textTheme.headlineMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      focusedPinTheme: PinTheme(
                        width: 64,
                        height: 64,
                        textStyle: textTheme.headlineMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      errorPinTheme: PinTheme(
                        width: 64,
                        height: 64,
                        textStyle: textTheme.headlineMedium?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: cs.errorContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.error,
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w500,
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
