import "package:flutter/material.dart";
import "../../theme/app_theme.dart";

import "../../core/session_store.dart";
import "../../routes/app_routes.dart";
import "../../widgets/section_header.dart";
import "../help/help_support_screen.dart";
import "../settings/settings_screen.dart";
import "change_password_screen.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await SessionStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.current;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = session.engineer.fullName.trim();
    final emp = session.engineer.empCode.trim();
    final mobile = session.engineer.mobileNo.trim();
    final initial = (name.isNotEmpty ? name[0].toUpperCase() : "U");

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text("Profile")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              const SectionHeader(title: "Account"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.softShadow,
                  border: Border.all(color: AppTheme.navy.withAlpha(8)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.sky.withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? "Engineer" : name,
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [if (emp.isNotEmpty) "Emp: $emp", if (mobile.isNotEmpty) "Mobile: $mobile"].join(" • "),
                            style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: "Account Actions"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(color: AppTheme.navy.withAlpha(8)),
                ),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.lock_reset_rounded,
                      title: "Change Password",
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChangePasswordScreen(sessionToken: session.token)),
                        );
                      },
                    ),
                    const Divider(),
                    _ProfileTile(
                      icon: Icons.settings_outlined,
                      title: "App Settings",
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    ),
                    const Divider(),
                    _ProfileTile(
                      icon: Icons.folder_open_outlined,
                      title: "Documents",
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.documents),
                    ),
                    const Divider(),
                    _ProfileTile(
                      icon: Icons.support_agent_rounded,
                      title: "Help & Support",
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                    ),
                    const Divider(),
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      title: "Logout",
                      isDestructive: true,
                      onTap: () => _logout(context),
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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppTheme.danger : AppTheme.navy, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isDestructive ? AppTheme.danger : AppTheme.navy,
          fontSize: 15,
        ),
      ),
      trailing: isDestructive ? null : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
