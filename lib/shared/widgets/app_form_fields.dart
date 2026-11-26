import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared mobile form controls. They keep labels, validation, focus, and
/// picker affordances visually consistent across every feature.
class AppFormFieldDecoration {
  const AppFormFieldDecoration._();

  static InputDecoration build(
    BuildContext context, {
    required String label,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? hintText,
    bool multiline = false,
    FloatingLabelBehavior floatingLabelBehavior = FloatingLabelBehavior.always,
  }) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = errorText != null && errorText.isNotEmpty ? colors.error : colors.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: borderColor, width: 2),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: floatingLabelBehavior,
      floatingLabelStyle: TextStyle(color: borderColor, fontWeight: FontWeight.w600),
      errorText: errorText,
      helperText: helperText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorMaxLines: 2,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: multiline ? 17 : 15),
      alignLabelWithHint: multiline,
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      errorBorder: border,
      focusedErrorBorder: border,
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({super.key, required this.label, this.controller, this.errorText, this.helperText, this.hintText, this.prefixIcon, this.suffixIcon, this.enabled = true, this.readOnly = false, this.onTap, this.onChanged, this.onSubmitted, this.inputFormatters, this.textCapitalization = TextCapitalization.none, this.keyboardType, this.textInputAction, this.autofocus = false, this.obscureText = false, this.maxLines = 1});
  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool obscureText;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    readOnly: readOnly,
    onTap: onTap,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofocus: autofocus,
    obscureText: obscureText,
    maxLines: obscureText ? 1 : maxLines,
    decoration: AppFormFieldDecoration.build(context, label: label, errorText: errorText, helperText: helperText, hintText: hintText, prefixIcon: prefixIcon, suffixIcon: suffixIcon, multiline: maxLines > 1),
  );
}

/// Form-aware variant for screens that use [Form] validation.
class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.hintText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    readOnly: readOnly,
    onTap: onTap,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    validator: validator,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    maxLines: maxLines,
    minLines: minLines,
    autofocus: autofocus,
    obscureText: obscureText,
    decoration: AppFormFieldDecoration.build(
      context,
      label: label,
      errorText: errorText,
      helperText: helperText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      hintText: hintText,
      multiline: maxLines > 1,
    ),
  );
}

class AppTextArea extends StatelessWidget {
  const AppTextArea({super.key, required this.label, this.controller, this.errorText, this.enabled = true, this.onChanged, this.minLines = 3, this.maxLines = 5});
  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    onChanged: onChanged,
    minLines: minLines,
    maxLines: maxLines,
    decoration: AppFormFieldDecoration.build(context, label: label, errorText: errorText, multiline: true),
  );
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({super.key, required this.label, required this.items, required this.onChanged, this.value, this.errorText, this.helperText, this.validator, this.enabled = true, this.icon, this.dropdownColor, this.selectedItemBuilder});
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final String? helperText;
  final FormFieldValidator<T>? validator;
  final bool enabled;
  final Widget? icon;
  final Color? dropdownColor;
  final DropdownButtonBuilder? selectedItemBuilder;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    icon: icon,
    dropdownColor: dropdownColor,
    decoration: AppFormFieldDecoration.build(context, label: label, errorText: errorText, helperText: helperText),
    items: items,
    onChanged: enabled ? onChanged : null,
    validator: validator,
    selectedItemBuilder: selectedItemBuilder,
  );
}

class AppPickerField extends StatelessWidget {
  const AppPickerField({super.key, required this.label, required this.value, required this.onTap, this.errorText, this.enabled = true});
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey('$label:$value'),
    initialValue: value,
    readOnly: true,
    enabled: enabled,
    onTap: onTap,
    decoration: AppFormFieldDecoration.build(context, label: label, errorText: errorText),
  );
}
