import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class TdsCertificatesScreen extends StatefulWidget {
  const TdsCertificatesScreen({super.key});

  @override
  State<TdsCertificatesScreen> createState() => _TdsCertificatesScreenState();
}

class _TdsCertificatesScreenState extends State<TdsCertificatesScreen> {
  late Future<List<dynamic>> _certificates;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _certificates = _load();
  }

  Future<List<dynamic>> _load() async {
    final dio = await ApiClient.instance.dio;
    final response = await dio.get('/api/v1/engineer/tds-certificates');
    return List<dynamic>.from(response.data as List);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _certificates = next);
    await next;
  }

  Future<void> _download(Map<String, dynamic> certificate) async {
    final certificateId = certificate['id']?.toString();
    if (certificateId == null || certificateId.isEmpty) return;
    setState(() => _downloadingId = certificateId);
    try {
      final dio = await ApiClient.instance.dio;
      final response = await dio.get('/api/v1/engineer/tds-certificates/$certificateId/download');
      final url = (response.data as Map)['download_url']?.toString();
      if (url == null || url.isEmpty) throw StateError('Download URL unavailable');

      final directory = await getTemporaryDirectory();
      final filename = certificate['original_filename']?.toString() ?? 'tds-certificate.pdf';
      final file = File('${directory.path}/$filename');
      await dio.download(
        url,
        file.path,
        options: Options(headers: {'Authorization': 'Bearer ${SessionStore.current?.token ?? ''}'}),
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'TDS certificate');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to download TDS certificate. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  String _period(Map<String, dynamic> certificate) {
    final year = certificate['financial_year']?.toString() ?? '';
    final quarter = certificate['quarter']?.toString();
    return quarter == null || quarter.isEmpty ? 'Financial year $year' : 'Financial year $year  •  $quarter';
  }

  String _publishedDate(Map<String, dynamic> certificate) {
    final value = certificate['published_at']?.toString() ?? '';
    final date = DateTime.tryParse(value);
    if (date == null) return 'Available now';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Published ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Tax Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh documents',
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _certificates,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <dynamic>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: colors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _PageIntro(count: rows.length),
                      const SizedBox(height: 20),
                      if (snapshot.connectionState != ConnectionState.done)
                        const Padding(
                          padding: EdgeInsets.only(top: 56),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError)
                        _StatusCard(
                          icon: Icons.cloud_off_outlined,
                          title: 'Documents are unavailable',
                          message: 'Pull down to try again.',
                          actionLabel: 'Try again',
                          onAction: _refresh,
                        )
                      else if (rows.isEmpty)
                        _StatusCard(
                          icon: Icons.folder_open_outlined,
                          title: 'No certificates yet',
                          message: 'Your Form 16 and Form 16A certificates will appear here once they are published.',
                          actionLabel: 'Refresh',
                          onAction: _refresh,
                        )
                      else
                        ...rows.map((item) {
                          final certificate = Map<String, dynamic>.from(item as Map);
                          final type = certificate['certificate_type']?.toString().replaceAll('_', ' ') ?? 'TDS Certificate';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CertificateCard(
                              certificate: certificate,
                              type: type,
                              period: _period(certificate),
                              publishedDate: _publishedDate(certificate),
                              downloading: _downloadingId == certificate['id']?.toString(),
                              onDownload: () => _download(certificate),
                            ),
                          );
                        }),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.receipt_long_outlined, color: colors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your tax certificates', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(count == 0 ? 'Download certificates when they are issued.' : '$count certificate${count == 1 ? '' : 's'} available to download.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onPrimary.withValues(alpha: 0.84))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate, required this.type, required this.period, required this.publishedDate, required this.downloading, required this.onDownload});

  final Map<String, dynamic> certificate;
  final String type;
  final String period;
  final String publishedDate;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.picture_as_pdf_outlined, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(type, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(period, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(20)),
                  child: const Text('AVAILABLE', style: TextStyle(color: Color(0xFF18794E), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(children: [Icon(Icons.calendar_today_outlined, size: 15, color: colors.onSurfaceVariant), const SizedBox(width: 7), Text(publishedDate, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: downloading ? null : onDownload,
                icon: downloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded),
                label: Text(downloading ? 'Preparing download...' : 'Download PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.message, required this.actionLabel, required this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.55))),
      child: Column(
        children: [
          Icon(icon, size: 42, color: colors.primary),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh_rounded), label: Text(actionLabel)),
        ],
      ),
    );
  }
}
