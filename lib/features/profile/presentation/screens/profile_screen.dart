import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/features/help/presentation/screens/help_support_screen.dart";
import "package:sitepulse_engineer/features/settings/presentation/screens/settings_screen.dart";
import "package:sitepulse_engineer/features/attendance/presentation/screens/attendance_screen.dart";
import "package:sitepulse_engineer/features/profile/presentation/bloc/profile_bloc.dart";
import "package:sitepulse_engineer/features/documents/presentation/bloc/documents_bloc.dart";
import "package:sitepulse_engineer/shared/models/engineer_document_model.dart";
import "package:sitepulse_engineer/features/shell/presentation/screens/app_shell.dart";
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

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  @override
  void initState() {
    super.initState();
    // Synchronize latest profile attributes (bank details, statutory info, weekly off)
    SessionStore.syncProfile().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onRefresh() async {
    await SessionStore.syncProfile();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SessionStore.notifier,
      builder: (context, session, _) {
        if (session == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final eng = session.engineer;
        final name = eng.fullName.trim();
        final emp = eng.empCode.trim();
        final mobile = eng.mobileNo.trim();
        final email = (eng.email ?? "").trim();
        final department = (eng.department ?? "").trim();
        final designation = (eng.designation ?? "").trim();
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
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(
                        context,
                        name: name,
                        empCode: emp,
                        initial: initial,
                        department: department,
                        designation: designation,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        "Employment Details",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildEmploymentCard(context, eng),
                      const SizedBox(height: 24),

                      Text(
                        "Personal Information",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(context, mobile, email, emp, eng.birthDate),
                      const SizedBox(height: 24),

                      if (_hasBankInfo(eng)) ...[
                        Text(
                          "Bank Account Details",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildBankCard(context, eng),
                        const SizedBox(height: 24),
                      ],

                      if (_hasStatutoryInfo(eng)) ...[
                        Text(
                          "Statutory Identification",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatutoryCard(context, eng),
                        const SizedBox(height: 24),
                      ],

                      Text(
                        "Account Actions",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildActionsCard(context, session.token, department),
                      const SizedBox(height: 32),

                      _buildLogoutButton(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _hasBankInfo(dynamic eng) {
    return (eng.bankAccountNumber != null && eng.bankAccountNumber!.trim().isNotEmpty) ||
        (eng.bankIfscCode != null && eng.bankIfscCode!.trim().isNotEmpty) ||
        (eng.bankName != null && eng.bankName!.trim().isNotEmpty);
  }

  bool _hasStatutoryInfo(dynamic eng) {
    return (eng.uanNumber != null && eng.uanNumber!.trim().isNotEmpty) ||
        (eng.panCardNumber != null && eng.panCardNumber!.trim().isNotEmpty) ||
        (eng.aadhaarCardNumber != null && eng.aadhaarCardNumber!.trim().isNotEmpty);
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required String name,
    required String empCode,
    required String initial,
    required String department,
    required String designation,
  }) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = [designation, department]
        .where((s) => s.isNotEmpty)
        .join(" • ");

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
              const Color(0xFF4338CA),
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
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? "Field Engineer" : name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      color: Color(0xFF10B981),
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

  Widget _buildEmploymentCard(BuildContext context, dynamic eng) {
    final cs = Theme.of(context).colorScheme;
    final dept = (eng.department ?? "").trim();
    final desig = (eng.designation ?? "").trim();
    final weeklyOff = eng.weeklyOffDaysDisplay;

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
          _buildInfoRow(
            context,
            Icons.engineering_rounded,
            "Stream / Department",
            dept.isNotEmpty ? dept : "General",
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _buildInfoRow(
            context,
            Icons.badge_outlined,
            "Designation",
            desig.isNotEmpty ? desig : "Field Engineer",
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _buildInfoRow(
            context,
            Icons.calendar_today_rounded,
            "Weekly Off",
            weeklyOff,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      BuildContext context, String mobile, String email, String emp, String? dob) {
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
          if (mobile.isNotEmpty && email.isNotEmpty)
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          if (email.isNotEmpty)
            _buildInfoRow(context, Icons.email_rounded, "Email Address", email),
          if (emp.isNotEmpty) ...[
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.badge_rounded, "Employee Code", emp),
          ],
          if (dob != null && dob.trim().isNotEmpty) ...[
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.cake_outlined, "Date of Birth", dob.trim()),
          ],
        ],
      ),
    );
  }

  Widget _buildBankCard(BuildContext context, dynamic eng) {
    final cs = Theme.of(context).colorScheme;
    final bankName = (eng.bankName ?? "").trim();
    final accNo = (eng.bankAccountNumber ?? "").trim();
    final ifsc = (eng.bankIfscCode ?? "").trim();
    final holder = (eng.bankAccountHolderName ?? "").trim();

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
          if (bankName.isNotEmpty)
            _buildInfoRow(context, Icons.account_balance_rounded, "Bank Name", bankName),
          if (accNo.isNotEmpty) ...[
            if (bankName.isNotEmpty)
              Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.credit_card_rounded, "Account Number", accNo),
          ],
          if (ifsc.isNotEmpty) ...[
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.pin_rounded, "IFSC Code", ifsc),
          ],
          if (holder.isNotEmpty) ...[
            Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.person_outline_rounded, "Account Holder", holder),
          ],
        ],
      ),
    );
  }

  Widget _buildStatutoryCard(BuildContext context, dynamic eng) {
    final cs = Theme.of(context).colorScheme;
    final pan = (eng.panCardNumber ?? "").trim();
    final aadhaar = (eng.aadhaarCardNumber ?? "").trim();
    final uan = (eng.uanNumber ?? "").trim();

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
          if (pan.isNotEmpty)
            _buildInfoRow(context, Icons.featured_play_list_outlined, "PAN Number", pan),
          if (aadhaar.isNotEmpty) ...[
            if (pan.isNotEmpty)
              Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.fingerprint_rounded, "Aadhaar Number", aadhaar),
          ],
          if (uan.isNotEmpty) ...[
            if (pan.isNotEmpty || aadhaar.isNotEmpty)
              Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
            _buildInfoRow(context, Icons.assignment_ind_outlined, "UAN (PF Number)", uan),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                const SizedBox(height: 3),
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

  Widget _buildActionsCard(BuildContext context, String sessionToken, String department) {
    final cs = Theme.of(context).colorScheme;
    final normDept = department.trim().toLowerCase();
    final int streamTotalRequired = normDept == "mechanical engineer" ? 6 : 5;

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
            icon: Icons.stars_rounded,
            title: "Referrals & Rewards",
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.referrals),
          ),
          Divider(height: 1, indent: 56, color: cs.outlineVariant.withValues(alpha: 0.5)),
          BlocBuilder<DocumentsBloc, DocumentsState>(
            builder: (context, docState) {
              final latestDocs = <String, EngineerDocument>{};
              for (final d in docState.documents) {
                if (d.documentType != 'other') {
                  latestDocs.putIfAbsent(d.documentType, () => d);
                }
              }
              final uploadedReq = latestDocs.values
                  .where((d) => d.fileUrl.trim().isNotEmpty && d.verificationStatus != 'REJECTED')
                  .length;
              final isLoaded = docState.status == DocumentsStatus.loaded;

              Widget? trailing;
              if (isLoaded) {
                final isComplete = uploadedReq >= streamTotalRequired;
                trailing = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isComplete
                        ? "$streamTotalRequired/$streamTotalRequired Done ✓"
                        : "$uploadedReq/$streamTotalRequired Uploaded",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? const Color(0xFF10B981) : cs.primary,
                    ),
                  ),
                );
              }

              return _ProfileMenuTile(
                icon: Icons.folder_open_rounded,
                title: "Documents",
                trailing: trailing,
                onTap: () {
                  final shell = AppShellScope.maybeOf(context);
                  if (shell != null) {
                    shell.setIndex(3);
                  } else {
                    Navigator.of(context).pushNamed(AppRoutes.documents);
                  }
                },
              );
            },
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
  final Widget? trailing;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    this.trailing,
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
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
