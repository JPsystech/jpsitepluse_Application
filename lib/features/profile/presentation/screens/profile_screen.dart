import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/shared/widgets/section_header.dart";
import "package:sitepulse_engineer/features/help/presentation/screens/help_support_screen.dart";
import "package:sitepulse_engineer/features/settings/presentation/screens/settings_screen.dart";
import "package:sitepulse_engineer/features/profile/presentation/bloc/profile_bloc.dart";
import "change_password_screen.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileBloc(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

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

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLogoutSuccess) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false, title: const Text("Profile")),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        const Color(0xFF4F46E5), // Indigo tone
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Theme.of(context).colorScheme.primary.withAlpha(50),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(30),
                          border: Border.all(
                              color: Colors.white.withAlpha(50), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? "Engineer" : name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  fontSize: 20),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (emp.isNotEmpty) "Emp: $emp",
                                if (mobile.isNotEmpty) "Mobile: $mobile"
                              ].join(" • "),
                              style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
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
                    boxShadow: Theme.of(context)
                        .extension<AppColorsExtension>()!
                        .cardShadow,
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(8)),
                  ),
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.lock_reset_rounded,
                        title: "Change Password",
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ChangePasswordScreen(
                                    sessionToken: session.token)),
                          );
                        },
                      ),
                      _ProfileTile(
                        icon: Icons.settings_outlined,
                        title: "App Settings",
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen())),
                      ),
                      _ProfileTile(
                        icon: Icons.folder_open_outlined,
                        title: "Documents",
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.documents),
                      ),
                      _ProfileTile(
                        icon: Icons.support_agent_rounded,
                        title: "Help & Support",
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const HelpSupportScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.read<ProfileBloc>().add(ProfileLogoutRequested()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withAlpha(80),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text("Logout",
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                const SizedBox(height: 20),
              ],
            ),
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

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 20, color: Colors.black38),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}
