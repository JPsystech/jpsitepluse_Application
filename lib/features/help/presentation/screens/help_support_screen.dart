import "package:flutter/material.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 1,
        title: Text(
          "Help & Support",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderBanner(context, cs),
              const SizedBox(height: 24),
              
              _buildSectionTitle(context, "Quick Actions"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      icon: Icons.support_agent_rounded,
                      title: "Contact Admin",
                      color: cs.primary,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      icon: Icons.bug_report_rounded,
                      title: "Report Issue",
                      color: Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(context, "Contact Information"),
              const SizedBox(height: 12),
              _buildContactCard(context, cs),
              const SizedBox(height: 32),

              _buildSectionTitle(context, "Frequently Asked Questions"),
              const SizedBox(height: 12),
              _buildFaqSection(context, cs),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            const Color(0xFF4338CA), // Deep Indigo
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.live_help_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How can we help?",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Find answers, report issues, or contact your administrator.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
            boxShadow: Theme.of(context).extension<AppColorsExtension>()?.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, ColorScheme cs) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildContactRow(
            context: context,
            icon: Icons.email_rounded,
            title: "Support Email",
            subtitle: "info@jpsystech.in",
            onTap: () {},
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withOpacity(0.5)),
          _buildContactRow(
            context: context,
            icon: Icons.phone_rounded,
            title: "Helpline",
            subtitle: "+91 1800-123-4567",
            onTap: () {},
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withOpacity(0.5)),
          _buildContactRow(
            context: context,
            icon: Icons.access_time_filled_rounded,
            title: "Office Hours",
            subtitle: "Mon - Sat, 9:00 AM to 6:00 PM",
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqSection(BuildContext context, ColorScheme cs) {
    final faqs = [
      {
        "q": "How do I punch in?",
        "a": "Navigate to the Attendance dashboard or use the Quick Punch button on the Home screen. Ensure your GPS is enabled, as you must be within the designated site radius to punch in."
      },
      {
        "q": "Why is my punch-in blocked?",
        "a": "Punch-ins are geofenced. If you are too far from the assignment location, the system will prevent the punch. Please ensure you are at the correct site and that your location permissions are granted."
      },
      {
        "q": "How do I upload custom documents?",
        "a": "Go to the Documents screen. Under 'Required Documents', you will see mandatory files. Scroll down to 'Custom Documents' and tap 'Add New' to upload additional files (PDF, JPG, PNG)."
      },
      {
        "q": "What happens if I forget to punch out?",
        "a": "If you do not punch out by midnight, the system will automatically close your shift (Auto-Close). Your timesheet will reflect 'Closed by system', and the hours may be flagged for review by your administrator."
      },
      {
        "q": "How can I view my past timesheets?",
        "a": "Tap on 'History' in the bottom navigation bar. You can view all past assignments, filter by specific dates, and download a PDF summary of your work history."
      },
    ];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: faqs.map((faq) {
          final isLast = faq == faqs.last;
          return Column(
            children: [
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  collapsedIconColor: cs.primary,
                  iconColor: cs.primary,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  title: Text(
                    faq["q"]!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                  ),
                  children: [
                    Text(
                      faq["a"]!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, indent: 20, endIndent: 20, color: cs.outlineVariant.withOpacity(0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
