import "package:flutter/material.dart";

import "package:sitepulse_engineer/shared/widgets/section_header.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              const SectionHeader(title: "App"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: Theme.of(context)
                      .extension<AppColorsExtension>()!
                      .softShadow,
                  border: Border.all(
                      color:
                          Theme.of(context).colorScheme.onSurface.withAlpha(8)),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: "App info",
                      subtitle: "JP SitePulse Engineer • v0.1.0",
                      color: const Color(0xFF3B82F6),
                    ),
                    Divider(
                      height: 1,
                      indent: 64,
                      color:
                          Theme.of(context).colorScheme.onSurface.withAlpha(15),
                    ),
                    _SettingsTile(
                      icon: Icons.tune_rounded,
                      title: "More settings",
                      subtitle: "Coming soon",
                      color: const Color(0xFF6366F1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100)),
        ],
      ),
    );
  }
}
