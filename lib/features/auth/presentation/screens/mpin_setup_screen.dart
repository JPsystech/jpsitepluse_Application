import "package:flutter/material.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/core/storage/mpin_store.dart";
import "package:sitepulse_engineer/shared/widgets/pin_pad.dart";

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

  void _onNumberPressed(int number) {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = "");
    }

    if (!_isConfirming) {
      if (_pin.length < 4) {
        setState(() => _pin += number.toString());
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _isConfirming = true;
              });
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += number.toString());
        if (_confirmPin.length == 4) {
          _verifyAndSave();
        }
      }
    }
  }

  void _onBackspacePressed() {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = "");
    }
    
    if (!_isConfirming) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      } else {
        // Go back to setup phase
        setState(() {
          _isConfirming = false;
          _pin = "";
        });
      }
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
            PinIndicator(length: currentLength),
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
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
