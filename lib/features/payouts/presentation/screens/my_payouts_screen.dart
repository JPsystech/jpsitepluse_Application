import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class MyPayoutsScreen extends StatefulWidget {
  const MyPayoutsScreen({super.key});

  @override
  State<MyPayoutsScreen> createState() => _MyPayoutsScreenState();
}

class _MyPayoutsScreenState extends State<MyPayoutsScreen> {
  late Future<({Map<String, dynamic> estimate, List<dynamic> history})> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<({Map<String, dynamic> estimate, List<dynamic> history})> _load() async {
    final dio = await ApiClient.instance.dio;
    final year = DateTime.now().year;
    final responses = await Future.wait([
      dio.get('/api/v1/engineer/payouts/estimate'),
      dio.get('/api/v1/engineer/payouts', queryParameters: {'year': year}),
    ]);
    final estData = Map<String, dynamic>.from(responses[0].data as Map);
    final histData = List<dynamic>.from(responses[1].data as List);
    debugPrint('[Payouts] Estimate response: $estData');
    debugPrint('[Payouts] History response: $histData');
    return (
      estimate: estData,
      history: histData,
    );
  }

  String _money(dynamic value) => '₹${(value as num? ?? 0).toStringAsFixed(2)}';

  String _month(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  String _formatNumber(dynamic val) {
    if (val == null) return "0";
    final num n = val as num;
    if (n == n.roundToDouble()) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(1);
  }

  num _amount(Map<String, dynamic> payout, String key) => payout[key] as num? ?? 0;

  num _totalDeductions(Map<String, dynamic> payout) =>
      _amount(payout, 'tds_amount') +
      _amount(payout, 'professional_tax_amount') +
      _amount(payout, 'employee_pf_amount') +
      _amount(payout, 'other_deductions');

  List<String> _deductionLabels(Map<String, dynamic> payout) => [
        if (_amount(payout, 'tds_amount') > 0) 'TDS ${_money(payout['tds_amount'])}',
        if (_amount(payout, 'professional_tax_amount') > 0) 'Professional Tax ${_money(payout['professional_tax_amount'])}',
        if (_amount(payout, 'employee_pf_amount') > 0) 'Employee PF ${_money(payout['employee_pf_amount'])}',
        if (_amount(payout, 'other_deductions') > 0) 'Other ${_money(payout['other_deductions'])}',
      ];

  Future<void> _downloadPayslip(Map<String, dynamic> payout) async {
    final runId = payout['payout_run_id']?.toString();
    if (runId == null || runId.isEmpty) return;
    try {
      final client = await ApiClient.instance.dio;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/payslip-${payout['wage_month']}.pdf');
      await client.download(
        '/api/v1/engineer/payouts/$runId/payslip.pdf',
        file.path,
        options: Options(headers: {
          'Authorization': 'Bearer ${SessionStore.current?.token ?? ''}',
        }),
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Payslip ${_month(payout['wage_month'].toString())}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to download payslip.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payouts'),
      ),
      body: FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Payout details are unavailable.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final estimate = data.estimate;
          final history = data.history;

          final isEstimate = estimate['is_estimate'] == true;
          final netPayoutVal = estimate['net_payout'];
          final paidDays = _formatNumber(estimate['attendance_days']);
          final pendingReviewDays = _formatNumber(estimate['pending_exception_days']);
          final deductions = _deductionLabels(estimate);
          final totalDeductions = _totalDeductions(estimate);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _data = _load();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Hero Expected Payout Card
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primaryContainer.withValues(alpha: 0.4),
                          cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.account_balance_wallet_rounded, color: cs.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isEstimate ? 'Expected Net Payout' : 'Current Net Payout',
                              style: textTheme.labelLarge?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _money(netPayoutVal),
                          style: textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gross Amount: ${_money(estimate['gross_payout'])}',
                          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Text(
                          'Deductions: ${_money(totalDeductions)}',
                          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (deductions.isNotEmpty)
                          Text(
                            deductions.join(' · '),
                            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF047857)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$paidDays Paid Days",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                ],
                              ),
                            ),
                            if (pendingReviewDays != '0')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pending_actions_rounded, size: 14, color: Color(0xFFB45309)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$pendingReviewDays Pending Review",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (isEstimate) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Estimated amount. Final payout may change after review and adjustments.',
                                  style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                Text(
                  '${DateTime.now().year} Payout History',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                ...history.map((item) {
                  final row = Map<String, dynamic>.from(item as Map);
                  final monthStr = _month(row['wage_month'].toString());
                  final paidDays = _formatNumber(row['attendance_days']);
                  final pendingReviewDays = _formatNumber(row['pending_exception_days']);
                  final deductions = _deductionLabels(row);

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  monthStr,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pendingReviewDays == '0'
                                      ? "$paidDays paid days"
                                      : "$paidDays paid days \u2022 $pendingReviewDays pending review",
                                  style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _money(row['net_payout']),
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                'Gross: ${_money(row['gross_payout'])}',
                                style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              Text(
                                'Deductions: ${_money(_totalDeductions(row))}',
                                style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              if (deductions.isNotEmpty)
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    deductions.join(' · '),
                                    textAlign: TextAlign.end,
                                    style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              if (row['payslip_available'] == true) ...[
                                const SizedBox(height: 6),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _downloadPayslip(row),
                                  icon: const Icon(Icons.download_rounded, size: 14),
                                  label: const Text("Payslip", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        'No generated payroll for this year yet.',
                        style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
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
