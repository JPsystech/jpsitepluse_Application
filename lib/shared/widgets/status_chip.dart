import "package:flutter/material.dart";
import "package:sitepulse_engineer/core/theme/app_theme.dart";

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primaryContainer;
    final fg = textColor ?? (color == null ? Theme.of(context).colorScheme.onPrimaryContainer : AppTheme.navy);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withAlpha(bg.alpha == 255 ? 40 : bg.alpha), // Ensure soft background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg.withAlpha(60), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg.alpha == 255 ? bg : fg,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: bg.alpha == 255 ? bg : fg,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

