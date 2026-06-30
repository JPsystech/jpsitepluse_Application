import "package:flutter/material.dart";
import "package:sitepulse_engineer/core/theme/app_theme.dart";

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.rows});

  final String title;
  final List<InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.navy.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppTheme.sky),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final r in rows) ...[
            _Row(label: r.label, value: r.value),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class InfoRow {
  final String label;
  final String value;

  InfoRow({required this.label, required this.value});
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted, fontWeight: FontWeight.w700);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

