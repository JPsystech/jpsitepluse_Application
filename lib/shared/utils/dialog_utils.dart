import 'package:flutter/material.dart';

/// Shows a standard confirmation dialog asking the user if they want to exit the app.
/// Returns `true` if the user confirms, `false` otherwise.
Future<bool> showExitConfirmationDialog(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Exit App"),
      content: const Text("Are you sure you want to exit the application?"),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            "Cancel",
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("Exit"),
        ),
      ],
    ),
  );

  return result ?? false;
}
