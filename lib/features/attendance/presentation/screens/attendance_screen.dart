import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sitepulse_engineer/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:sitepulse_engineer/shared/widgets/section_header.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceBloc(),
      child: const _AttendanceView(),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: "Attendance Stats"),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: Theme.of(context).extension<AppColorsExtension>()!.softShadow,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(8)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.access_time_rounded,
                            size: 48, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Attendance Stats Placeholder",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Your active punch-in logic is currently handled in the Home Screen. Dedicated attendance stats will be built here in the future.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.4),
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
