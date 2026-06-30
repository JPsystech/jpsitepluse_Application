import "package:flutter/material.dart";

import "package:sitepulse_engineer/shared/widgets/section_header.dart";

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              const SectionHeader(title: "App"),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text("App info", style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text("JP SitePulse Engineer • v0.1.0", style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.tune),
                      title: Text("More settings", style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text("Coming soon", style: TextStyle(fontWeight: FontWeight.w700)),
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

