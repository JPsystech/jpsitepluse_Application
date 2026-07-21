import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sitepulse_engineer/core/theme/app_colors_extension.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/features/help/presentation/screens/help_support_screen.dart";
import "package:sitepulse_engineer/features/settings/presentation/screens/settings_screen.dart";
import "package:sitepulse_engineer/features/attendance/presentation/screens/attendance_screen.dart";
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
    final email = (session.engineer.email ?? "").trim();
    final initial = (name.isNotEmpty ? name[0].toUpperCase() : "U");

    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLogoutSuccess) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            "My Profile",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          centerTitle: true,
          scrolledUnderElevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileHeader(context, name, emp, initial),
                const SizedBox(height: 24),
                
                Text(
                  "Personal Information",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(context, mobile, email, emp),
                const SizedBox(height: 24),
                
                Text(
                  "Account Actions",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 12),
                _buildActionsCard(context, session.token),
                const SizedBox(height: 32),
                
                _buildLogoutButton(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String empCode, String initial) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
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
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_rounded, size: 16, color: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? "Field Engineer" : name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // Success Green
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Active • Emp: $empCode",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String mobile, String email, String emp) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          if (mobile.isNotEmpty)
            _buildInfoRow(context, Icons.phone_rounded, "Mobile Number", mobile),
          if (mobile.isNotEmpty && (email.isNotEmpty || emp.isNotEmpty))
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          if (email.isNotEmpty)
            _buildInfoRow(context, Icons.email_rounded, "Email Address", email),
          if (email.isNotEmpty && emp.isNotEmpty)
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          if (emp.isNotEmpty)
            _buildInfoRow(context, Icons.badge_rounded, "Employee Code", emp),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
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
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, String sessionToken) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ProfileMenuTile(
            icon: Icons.lock_reset_rounded,
            title: "Change Password",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(sessionToken: sessionToken)),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _ProfileMenuTile(
            icon: Icons.analytics_rounded,
            title: "Attendance Dashboard",
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AttendanceScreen(sessionToken: sessionToken))),
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _ProfileMenuTile(
            icon: Icons.settings_rounded,
            title: "App Settings",
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _ProfileMenuTile(
            icon: Icons.folder_open_rounded,
            title: "Documents",
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.documents),
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _ProfileMenuTile(
            icon: Icons.support_agent_rounded,
            title: "Help & Support",
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: () => context.read<ProfileBloc>().add(ProfileLogoutRequested()),
      style: FilledButton.styleFrom(
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.error,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text(
        "Logout",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
