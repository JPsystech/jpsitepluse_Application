import "dart:io";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "../theme/app_theme.dart";

class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.url});

  final String url;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = widget.url.split("/").last.split("?").first;
        // Ensure it has an extension
        final extension = fileName.contains(".") ? "" : ".jpg";
        final file = File("${tempDir.path}/$fileName$extension");
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          await Share.shareXFiles([XFile(file.path)], text: "Save or share image");
        }
      } else {
        throw Exception("Failed to download image");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if (_isDownloading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _downloadImage,
              tooltip: "Download/Share",
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: widget.url,
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (_, __, ___) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white, size: 64),
                  SizedBox(height: 16),
                  Text("Failed to load image", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),

    );
  }
}
