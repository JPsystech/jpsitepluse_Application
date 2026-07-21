import "package:flutter/material.dart";
import "package:flutter/services.dart";

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.showLabel = true,
    this.prefixIcon,
    this.suffixIcon,
    this.onSubmitted,
    this.enabled,
    this.maxLines = 1,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final bool showLabel;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final bool? enabled;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? helperText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = (hint ?? label).trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: textInputAction,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            hintText: placeholder.isEmpty ? null : placeholder,
            hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 22, color: cs.onSurfaceVariant),
            suffixIcon: suffixIcon,
            helperText: helperText,
            helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.error, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
