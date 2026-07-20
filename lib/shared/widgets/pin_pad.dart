import "package:flutter/material.dart";
import "package:flutter/services.dart";

class PinPadWidget extends StatelessWidget {
  final void Function(int) onNumberPressed;
  final VoidCallback onBackspacePressed;
  final bool hasBiometric;
  final VoidCallback? onBiometricPressed;

  const PinPadWidget({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    this.hasBiometric = false,
    this.onBiometricPressed,
  });

  Widget _buildNumberButton(BuildContext context, int number) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onNumberPressed(number);
      },
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface.withAlpha(20),
        ),
        child: Text(
          number.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(
          icon,
          size: 28,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton(context, 1),
            _buildNumberButton(context, 2),
            _buildNumberButton(context, 3),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton(context, 4),
            _buildNumberButton(context, 5),
            _buildNumberButton(context, 6),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton(context, 7),
            _buildNumberButton(context, 8),
            _buildNumberButton(context, 9),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            hasBiometric && onBiometricPressed != null
                ? _buildIconButton(context, Icons.fingerprint, onBiometricPressed!)
                : const SizedBox(width: 80, height: 80),
            _buildNumberButton(context, 0),
            _buildIconButton(context, Icons.backspace_outlined, onBackspacePressed),
          ],
        ),
      ],
    );
  }
}

class PinIndicator extends StatelessWidget {
  final int length;
  final int maxLength;

  const PinIndicator({
    super.key,
    required this.length,
    this.maxLength = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final isFilled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withAlpha(50),
          ),
        );
      }),
    );
  }
}
