import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:sitepulse_engineer/core/error/error_handler.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.url,
    this.title = "Document",
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isDownloading = false;

  Future<void> _downloadAndShare() async {
    setState(() => _isDownloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final uri = Uri.parse(widget.url);
      final filename = uri.pathSegments.last.isEmpty ? "document.pdf" : uri.pathSegments.last;
      final file = File('${dir.path}/$filename');

      await Dio().download(widget.url, file.path);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File downloaded successfully!')),
      );

      // Optionally share it so the user can easily save it to their phone
      await Share.shareXFiles([XFile(file.path)], text: 'Downloaded PDF Document');

    } catch (e) {
      final appError = ErrorHandler.handle(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download: ${appError.userMessage}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: _isDownloading ? null : _downloadAndShare,
          ),
        ],
      ),
      body: SfPdfViewer.network(
        widget.url,
        key: _pdfViewerKey,
        canShowScrollHead: false,
        canShowScrollStatus: false,
      ),
    );
  }
}
