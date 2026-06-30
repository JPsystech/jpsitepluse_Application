import "package:flutter/material.dart";

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

