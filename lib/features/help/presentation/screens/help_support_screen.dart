import "package:flutter/material.dart";

import "package:sitepulse_engineer/shared/widgets/section_header.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              const SectionHeader(title: "Contact"),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: Theme.of(context).extension<AppColorsExtension>()!.softShadow,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.support_agent_rounded,
                                size: 24, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Need help?",
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: -0.2)),
                                const SizedBox(height: 4),
                                Text(
                                  "Contact your admin to reset password or resolve assignment issues.",
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: "Basics"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: Theme.of(context).extension<AppColorsExtension>()!.softShadow,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Punch In/Out",
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: -0.2)),
                                const SizedBox(height: 6),
                                Text(
                                  "Punch in when you arrive at the site. Punch out with remarks when you finish. Ensure location permission is enabled.",
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(15)),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.edit_note_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Timesheet",
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: -0.2)),
                                const SizedBox(height: 6),
                                Text(
                                  "Submit a timesheet entry with a progress photo and a short description of your work.",
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
