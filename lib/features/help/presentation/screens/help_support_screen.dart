import "package:flutter/material.dart";

import "package:sitepulse_engineer/shared/widgets/section_header.dart";

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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Need help?", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                      SizedBox(height: 8),
                      Text(
                        "Contact your admin to reset password or resolve assignment issues.",
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const SectionHeader(title: "Basics"),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Punch In/Out", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                      SizedBox(height: 8),
                      Text(
                        "Punch in when you arrive at the site. Punch out with remarks when you finish. Ensure location permission is enabled.",
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 14),
                      Text("Timesheet", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                      SizedBox(height: 8),
                      Text(
                        "Submit a timesheet entry with a progress photo and a short description of your work.",
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
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

