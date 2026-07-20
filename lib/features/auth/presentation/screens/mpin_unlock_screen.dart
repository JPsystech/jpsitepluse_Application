import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/storage/mpin_store.dart";
import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/shared/widgets/pin_pad.dart";

class MpinUnlockScreen extends StatefulWidget {
  const MpinUnlockScreen({super.key});

  @override
  State<MpinUnlockScreen> createState() => _MpinUnlockScreenState();
}

class _MpinUnlockScreenState extends State<MpinUnlockScreen> {
  String _pin = "";
  String _errorMessage = "";

  void _onNumberPressed(int number) {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = "");
    }

    if (_pin.length < 4) {
      setState(() => _pin += number.toString());
      if (_pin.length == 4) {
        _verifyMpin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = "");
    }

    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _verifyMpin() async {
    final isValid = await MpinStore.verifyMpin(_pin);
    if (isValid) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.app, (route) => false);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = "Incorrect MPIN";
        _pin = "";
      });
    }
  }

  Future<void> _handleForgotMpin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset MPIN"),
        content: const Text(
            "To reset your MPIN, you must log out and log back in with your password. Do you want to continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SessionStore.clear();
      await MpinStore.clearMpin();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineerName = SessionStore.current?.engineer.fullName ?? "Engineer";

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Text(
              "Welcome back,",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              engineerName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 48),
            PinIndicator(length: _pin.length),
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
            PinPadWidget(
              onNumberPressed: _onNumberPressed,
              onBackspacePressed: _onBackspacePressed,
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: _handleForgotMpin,
              child: Text(
                "Forgot MPIN? Log out",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
