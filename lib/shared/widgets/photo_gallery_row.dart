import 'package:flutter/material.dart';
import 'package:sitepulse_engineer/core/theme/app_theme.dart';
import 'package:sitepulse_engineer/shared/widgets/image_viewer.dart';

class PhotoGalleryRow extends StatelessWidget {
  const PhotoGalleryRow({
    super.key,
    required this.label,
    required this.urls,
    this.maxThumbs = 8,
  });

  final String label;
  final List<String> urls;
  final int maxThumbs;

  Widget _thumb(BuildContext context, String url) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewer(url: url),
            fullscreenDialog: true,
          ),
        );
      },
      child: Hero(
        tag: url,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 84,
              height: 84,
              color: AppTheme.bg,
              child: const Icon(Icons.broken_image_outlined, color: AppTheme.muted),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 84,
                height: 84,
                color: AppTheme.bg,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final shown = urls.take(maxThumbs).toList();
    final hiddenCount = urls.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
            ),
            Text("${urls.length}", style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length + (hiddenCount > 0 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              if (idx == shown.length) {
                return Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      "+$hiddenCount",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.navy, fontSize: 18),
                    ),
                  ),
                );
              }
              return _thumb(context, shown[idx]);
            },
          ),
        ),
      ],
    );
  }
}
