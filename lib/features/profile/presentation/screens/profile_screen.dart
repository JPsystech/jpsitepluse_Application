import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:sitepulse_engineer/core/config/api_config.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/storage/session_store.dart";
import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/features/help/presentation/screens/help_support_screen.dart";
import "package:sitepulse_engineer/features/settings/presentation/screens/settings_screen.dart";
import "package:sitepulse_engineer/features/attendance/presentation/screens/attendance_screen.dart";
import "package:sitepulse_engineer/features/payouts/presentation/screens/my_payouts_screen.dart";
import "package:sitepulse_engineer/features/profile/presentation/bloc/profile_bloc.dart";
import "package:sitepulse_engineer/features/documents/presentation/bloc/documents_bloc.dart";
import "package:sitepulse_engineer/features/onboarding/data/models/onboarding_status_model.dart";
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
  bool _isUploadingPhoto = false;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickAndUploadProfilePhoto(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _isUploadingPhoto = true);
      await SessionStore.uploadProfilePhoto(picked.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile photo updated successfully"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update profile photo: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Profile Photo?"),
        content: const Text(
          "Are you sure you want to remove your profile photo? This will not affect your Selfie / Passport Size Photo in My Documents.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      setState(() => _isUploadingPhoto = true);
      await SessionStore.removeProfilePhoto();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile photo removed")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to remove profile photo: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showFullPhotoDialog(BuildContext context, String fullUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              SizedBox(
                width: double.infinity,
                height: 420,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    fullUrl,
                    headers: (SessionStore.current?.token.trim().isNotEmpty ?? false)
                        ? {"Authorization": "Bearer ${SessionStore.current!.token.trim()}"}
                        : null,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfilePhotoOptions(BuildContext context, String? photoUrl) {
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    final fullUrl = hasPhoto ? resolveMaybeRelativeUrl(photoUrl) : "";

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "Profile Photo",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_camera_rounded),
                  ),
                  title: const Text("Take Photo"),
                  subtitle: const Text("Capture a new profile photo using camera"),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _pickAndUploadProfilePhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library_rounded),
                  ),
                  title: const Text("Choose from Gallery"),
                  subtitle: const Text("Select an existing photo from your phone"),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _pickAndUploadProfilePhoto(ImageSource.gallery);
                  },
                ),
                if (hasPhoto && fullUrl.isNotEmpty) ...[
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.fullscreen_rounded),
                    ),
                    title: const Text("View Full Photo"),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _showFullPhotoDialog(context, fullUrl);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.redAccent,
                      child: const Icon(Icons.delete_outline_rounded),
                    ),
                    title: const Text(
                      "Remove Profile Photo",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _removeProfilePhoto();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
    // Synchronize latest profile attributes (bank details, statutory info, weekly off)
    resolveApiBaseUrl();
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
                        profilePhotoUrl: eng.profilePhotoUrl,
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
    String? profilePhotoUrl,
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
            GestureDetector(
              onTap: _isUploadingPhoto
                  ? null
                  : () => _showProfilePhotoOptions(context, profilePhotoUrl),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: (profilePhotoUrl != null &&
                              profilePhotoUrl.trim().isNotEmpty &&
                              resolveMaybeRelativeUrl(profilePhotoUrl).isNotEmpty)
                          ? Image.network(
                              resolveMaybeRelativeUrl(profilePhotoUrl),
                              headers: (SessionStore.current?.token.trim().isNotEmpty ?? false)
                                  ? {"Authorization": "Bearer ${SessionStore.current!.token.trim()}"}
                                  : null,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 40,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 40,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (_isUploadingPhoto)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 17,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
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
    final requiredTypes = OnboardingStatusModel.getRequiredTypesForDepartment(department);
    final int streamTotalRequired = requiredTypes.length;

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
            icon: Icons.account_balance_wallet_rounded,
            title: "My Payouts",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyPayoutsScreen()),
            ),
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
              final isLoaded = docState.status == DocumentsStatus.loaded;

              Widget? trailing;
              if (isLoaded) {
                if (streamTotalRequired == 0) {
                  final totalUploaded = docState.documents
                      .where((d) => d.fileUrl.trim().isNotEmpty)
                      .length;
                  trailing = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$totalUploaded Uploaded",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  );
                } else {
                  final approvedReq = requiredTypes
                      .where((t) =>
                          latestDocs[t]?.fileUrl.trim().isNotEmpty == true &&
                          latestDocs[t]?.verificationStatus.toUpperCase() == 'APPROVED')
                      .length;
                  final rejectedReq = requiredTypes
                      .where((t) =>
                          latestDocs[t]?.verificationStatus.toUpperCase() == 'REJECTED')
                      .length;
                  final remainingCount = streamTotalRequired - approvedReq;
                  final isAllApproved = remainingCount == 0;

                  final badgeColor = isAllApproved
                      ? const Color(0xFF10B981)
                      : rejectedReq > 0
                          ? cs.error
                          : cs.primary;

                  final badgeLabel = isAllApproved
                      ? "$streamTotalRequired/$streamTotalRequired Approved ✓"
                      : rejectedReq > 0
                          ? "$rejectedReq Rejected · $remainingCount Remaining"
                          : "$remainingCount Required Remaining";

                  trailing = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  );
                }
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
