import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

import "package:sitepulse_engineer/core/router/app_routes.dart";
import "package:sitepulse_engineer/shared/widgets/primary_button.dart";
import "package:sitepulse_engineer/features/terms/presentation/bloc/terms_bloc.dart";

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TermsBloc(),
      child: const _TermsView(),
    );
  }
}

class _TermsView extends StatefulWidget {
  const _TermsView();

  @override
  State<_TermsView> createState() => _TermsViewState();
}

class _TermsViewState extends State<_TermsView> {
  bool accepted = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Terms & Conditions")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              BlocConsumer<TermsBloc, TermsState>(listener: (context, state) {
            if (state is TermsSuccess) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.app, (_) => false);
            }
          }, builder: (context, state) {
            final isSaving = state is TermsSaving;
            final error = state is TermsError ? state.message : null;

            return Column(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: DefaultTextStyle(
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("JP SitePulse Engineer App",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 10),
                              Text(
                                "By using this application, you agree to follow your company policies and site safety rules. "
                                "You must provide accurate attendance and work information. Photos and location may be collected "
                                "for verification and compliance purposes.",
                              ),
                              SizedBox(height: 10),
                              Text("1. Attendance",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text(
                                  "Punch in/out only when you are at the assigned site. Do not share your account."),
                              SizedBox(height: 10),
                              Text("2. Location & Photos",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text(
                                  "Location and photos may be required to complete attendance and timesheets."),
                              SizedBox(height: 10),
                              Text("3. Misuse",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text(
                                  "Any misuse or false reporting may lead to disciplinary action."),
                              SizedBox(height: 10),
                              Text("4. Support",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              SizedBox(height: 6),
                              Text(
                                  "For issues, contact your admin/support team."),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: accepted,
                      onChanged: isSaving
                          ? null
                          : (v) {
                              setState(() {
                                accepted = v ?? false;
                              });
                            },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: isSaving
                            ? null
                            : () {
                                setState(() {
                                  accepted = !accepted;
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            "I have read and agree to the Terms & Conditions",
                            style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error,
                        style: const TextStyle(
                            color: Color(0xFF9F1239),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 8),
                PrimaryButton(
                  label: isSaving ? "Saving..." : "Continue",
                  onPressed: accepted && !isSaving
                      ? () => context.read<TermsBloc>().add(TermsAccepted())
                      : null,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
