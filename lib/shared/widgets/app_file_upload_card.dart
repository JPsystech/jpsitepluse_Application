import 'package:flutter/material.dart';

/// A consistent tap-to-upload card for attachment fields across the app.
class AppFileUploadCard extends StatelessWidget {
  const AppFileUploadCard({
    super.key,
    required this.uploadLabel,
    required this.supportText,
    required this.onTap,
    this.fileName,
    this.fileSizeBytes,
    this.onClear,
    this.enabled = true,
    this.fileIcon = Icons.description_rounded,
  });

  final String uploadLabel;
  final String supportText;
  final VoidCallback? onTap;
  final String? fileName;
  final int? fileSizeBytes;
  final VoidCallback? onClear;
  final bool enabled;
  final IconData fileIcon;

  bool get _hasFile => fileName != null && fileName!.trim().isNotEmpty;

  String get _fileSizeLabel {
    final bytes = fileSizeBytes ?? 0;
    final kilobytes = (bytes / 1024).round();
    return kilobytes > 1024
        ? '${(kilobytes / 1024).toStringAsFixed(1)} MB'
        : '$kilobytes KB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_hasFile) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF10B981)),
        ),
        color: const Color(0xFFECFDF5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(fileIcon, color: const Color(0xFF047857), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      _fileSizeLabel,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Remove file',
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 32, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              uploadLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              supportText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
