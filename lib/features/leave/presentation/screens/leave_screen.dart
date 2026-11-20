import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sitepulse_engineer/core/network/api_client.dart';
import 'package:sitepulse_engineer/core/services/notification_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> _requests;
  var _historyVersion = 0;
  final Set<String> _expandedRequestIds = {};
  String? _cancellingRequestId;
  String? _earlyReturnRequestId;

  @override
  void initState() {
    super.initState();
    _requests = _load();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.leaveDecisionVersion.addListener(_reloadAfterLeaveDecision);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.leaveDecisionVersion.removeListener(_reloadAfterLeaveDecision);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reload());
    }
  }

  void _reloadAfterLeaveDecision() {
    if (mounted) unawaited(_reload());
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final dio = await ApiClient.instance.dio;
    final response = await dio.get(
      '/api/v1/engineer/leave-requests',
      queryParameters: {'refresh': DateTime.now().microsecondsSinceEpoch},
      options: Options(headers: const {'Cache-Control': 'no-cache'}),
    );
    return List<dynamic>.from(response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _reload() async {
    final request = _load();
    if (mounted) {
      setState(() {
        _requests = request;
        _historyVersion++;
      });
    }
    await request;
  }

  String _date(DateTime? value) {
    if (value == null) return 'Select date';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _leaveFieldDecoration(
    BuildContext context, {
    required String label,
    IconData? icon,
    String? errorText,
  }) {
    final colors = Theme.of(context).colorScheme;
    final hasError = errorText != null && errorText.isNotEmpty;
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      errorMaxLines: 3,
      errorStyle: TextStyle(color: colors.error, fontWeight: FontWeight.w600),
      prefixIcon: icon == null ? null : Icon(icon, color: hasError ? colors.error : colors.primary),
      suffixIcon: hasError ? Icon(Icons.error_rounded, color: colors.error) : null,
      filled: true,
      fillColor: hasError ? colors.errorContainer.withValues(alpha: 0.1) : colors.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: hasError ? colors.error : colors.outline.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: hasError ? colors.error : colors.primary, width: 1.5)),
    );
  }

  Future<void> _openApplyLeaveSheet() async {
    var reason = '';
    DateTime? fromDate;
    DateTime? toDate;
    var isSubmitting = false;
    String? fromDateError;
    String? toDateError;
    String? reasonError;

    final applied = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Apply for leave', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Choose the leave dates and provide a reason for your coordinator.', style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: fromDateError != null ? Theme.of(sheetContext).colorScheme.error : Theme.of(sheetContext).colorScheme.outline)), onPressed: isSubmitting ? null : () async {
                    final selected = await showDatePicker(context: sheetContext, initialDate: fromDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(DateTime.now().year + 2));
                    if (selected != null) setSheetState(() { fromDate = selected; if (toDate != null && toDate!.isBefore(selected)) toDate = selected; fromDateError = null; });
                  }, child: Text('From: ${_date(fromDate)}')), if (fromDateError != null) Padding(padding: const EdgeInsets.only(top: 4, left: 12), child: Text(fromDateError!, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error, fontWeight: FontWeight.w600))) ])),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: toDateError != null ? Theme.of(sheetContext).colorScheme.error : Theme.of(sheetContext).colorScheme.outline)), onPressed: isSubmitting ? null : () async {
                    final selected = await showDatePicker(context: sheetContext, initialDate: toDate ?? fromDate ?? DateTime.now(), firstDate: fromDate ?? DateTime(2020), lastDate: DateTime(DateTime.now().year + 2));
                    if (selected != null) setSheetState(() { toDate = selected; toDateError = null; });
                  }, child: Text('To: ${_date(toDate)}')), if (toDateError != null) Padding(padding: const EdgeInsets.only(top: 4, left: 12), child: Text(toDateError!, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error, fontWeight: FontWeight.w600))) ])),
                ],
              ),
              const SizedBox(height: 12),
              TextField(minLines: 3, maxLines: 5, enabled: !isSubmitting, onChanged: (value) { reason = value; if (reasonError != null) setSheetState(() => reasonError = null); }, decoration: _leaveFieldDecoration(sheetContext, label: 'Reason', errorText: reasonError)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.of(sheetContext).pop(), child: const Text('Cancel')),
                FilledButton(onPressed: isSubmitting ? null : () async {
                  if (fromDate == null || toDate == null || toDate!.isBefore(fromDate!) || reason.trim().isEmpty) {
                    setSheetState(() {
                      fromDateError = fromDate == null ? 'Select a start date.' : null;
                      toDateError = toDate == null ? 'Select an end date.' : toDate!.isBefore(fromDate!) ? 'End date cannot be before start date.' : null;
                      reasonError = reason.trim().isEmpty ? 'Enter a reason for leave.' : null;
                    });
                    return;
                  }
                  setSheetState(() => isSubmitting = true);
                  try {
                    final dio = await ApiClient.instance.dio;
                    final response = await dio.post('/api/v1/engineer/leave-requests', data: {'from_date': _date(fromDate), 'to_date': _date(toDate), 'reason': reason.trim()});
                    final responseError = _responseError(response.data);
                    if (responseError != null) {
                      if (sheetContext.mounted) {
                        setSheetState(() {
                          isSubmitting = false;
                          toDateError = responseError;
                        });
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(responseError)));
                      }
                      return;
                    }
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(Map<String, dynamic>.from(response.data as Map));
                    }
                  } on DioException catch (error) {
                    final errorMessage = _apiError(error, 'Unable to submit leave.');
                    if (sheetContext.mounted) {
                      setSheetState(() {
                        isSubmitting = false;
                        if (error.response?.data != null) toDateError = errorMessage;
                      });
                      ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(errorMessage)));
                    }
                  }
                }, child: Text(isSubmitting ? 'Submitting...' : 'Submit leave request')),
              ]),
            ],
          ),
        ),
      ),
    );
    if (applied != null && mounted) {
      setState(() {
        _requests = _requests.then((items) => [applied, ...items.where((item) => item['id'] != applied['id'])]);
        _historyVersion++;
      });
      _notice('Leave request submitted.');
    }
  }

  Future<void> _cancel(Map<String, dynamic> request) async {
    final requestId = request['id'].toString();
    if (_cancellingRequestId != null) return;
    setState(() => _cancellingRequestId = requestId);
    try {
      final dio = await ApiClient.instance.dio;
      final response = await dio.post('/api/v1/engineer/leave-requests/${request['id']}/cancel');
      final responseError = _responseError(response.data);
      if (responseError != null) {
        _notice(responseError);
        return;
      }
      if (response.data is! Map) {
        _notice('Leave cancellation could not be confirmed. Please refresh and try again.');
        return;
      }
      final updatedRequest = Map<String, dynamic>.from(response.data as Map);
      if (mounted) {
        setState(() {
          _requests = _requests.then((items) => items.map((item) => item['id'] == updatedRequest['id'] ? updatedRequest : item).toList());
          _historyVersion++;
        });
      }
      _notice('Leave request cancelled.');
    } on DioException catch (error) {
      _notice(_apiError(error, 'Unable to cancel leave.'));
    } finally {
      if (mounted) setState(() => _cancellingRequestId = null);
    }
  }

  Future<void> _earlyReturn(Map<String, dynamic> request) async {
    final requestId = request['id'].toString();
    if (_cancellingRequestId != null || _earlyReturnRequestId != null) return;
    final fromDate = DateTime.parse(request['from_date'].toString());
    final toDate = DateTime.parse(request['to_date'].toString());
    final date = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: fromDate,
      lastDate: toDate,
    );
    if (date == null) return;

    setState(() => _earlyReturnRequestId = requestId);
    try {
      final dio = await ApiClient.instance.dio;
      final response = await dio.post(
        '/api/v1/engineer/leave-requests/${request['id']}/return-early',
        data: {'return_date': _date(date)},
      );
      final responseError = _responseError(response.data);
      if (responseError != null) {
        _notice(responseError);
        return;
      }
      if (response.data is! Map) {
        _notice('Early-return request could not be confirmed. Please refresh and try again.');
        return;
      }
      final updatedRequest = Map<String, dynamic>.from(response.data as Map);
      if (mounted) {
        setState(() {
          _requests = _requests.then((items) => items.map((item) => item['id'] == updatedRequest['id'] ? updatedRequest : item).toList());
          _historyVersion++;
        });
      }
      _notice('Early-return request submitted.');
    } on DioException catch (error) {
      _notice(_apiError(error, 'Unable to request early return.'));
    } finally {
      if (mounted) setState(() => _earlyReturnRequestId = null);
    }
  }

  String _apiError(DioException error, String fallback) {
    return _responseError(error.response?.data) ?? fallback;
  }

  String? _responseError(Object? data) {
    if (data is! Map) return null;

    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail;

    final error = data['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    return null;
  }

  String _displayStatus(Map<String, dynamic> item) {
    final status = item['status'].toString();
    final days = List<dynamic>.from(item['days'] as List? ?? const []);
    final hasCancelled = days.any((day) => day is Map && day['state'] == 'CANCELLED');
    final hasLop = days.any((day) => day is Map && day['state'] == 'APPROVED_LOP');
    if (status == 'CANCELLATION_REQUESTED') return 'EARLY RETURN PENDING';
    if (status == 'APPROVED' && hasCancelled && hasLop) return 'PARTIALLY RETURNED';
    if (status == 'CANCELLED' && item['cancellation_requested_return_date'] != null && hasCancelled) return 'RETURNED EARLY';
    return status.replaceAll('_', ' ');
  }

  String _dayStateLabel(String state) {
    switch (state) {
      case 'APPROVED_LOP':
        return 'LOP';
      case 'PRESENT_OVERRIDE':
        return 'PRESENT';
      case 'CANCELLED':
        return 'Returned';
      default:
        return state.replaceAll('_', ' ');
    }
  }

  String _formatDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _dateRange(Map<String, dynamic> request) {
    final from = _formatDate(request['from_date']);
    final to = _formatDate(request['to_date']);
    return from == to ? from : '$from - $to';
  }

  Color _statusColor(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;
    if (status.contains('PENDING')) return colors.tertiary;
    if (status.contains('REJECTED')) return colors.error;
    if (status.contains('RETURNED') || status == 'CANCELLED') return colors.secondary;
    return colors.primary;
  }

  void _notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Management')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Apply for leave',
        onPressed: () => unawaited(_openApplyLeaveSheet()),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Request history', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Track your leave requests and their latest status.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_historyVersion),
              future: _requests,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Unable to load leave requests.'),
                  );
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No leave requests yet.'),
                  );
                }

                return Column(
                  children: items.map((item) {
                    final status = item['status'].toString();
                    final days = List<dynamic>.from(item['days'] as List? ?? const []);
                    final hasCancelledDay = days.any((day) => day is Map && day['state'] == 'CANCELLED');
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final fromDate = DateTime.parse(item['from_date'].toString());
                    final toDate = DateTime.parse(item['to_date'].toString());
                    final leaveHasNotStarted = today.isBefore(fromDate);
                    final leaveIsInProgress = !today.isBefore(fromDate) && !today.isAfter(toDate);
                    final canCancel = (status == 'PENDING' || (status == 'APPROVED' && !hasCancelledDay)) && leaveHasNotStarted;
                    final canReturnEarly = status == 'APPROVED' && !hasCancelledDay && leaveIsInProgress;
                    final displayStatus = _displayStatus(item);
                    final statusColor = _statusColor(context, displayStatus);
                    final requestId = item['id'].toString();
                    final isExpanded = _expandedRequestIds.contains(requestId);
                    final isCancelling = _cancellingRequestId == requestId;
                    final isRequestingEarlyReturn = _earlyReturnRequestId == requestId;
                    final isActionInProgress = isCancelling || isRequestingEarlyReturn;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() {
                                  if (isExpanded) {
                                    _expandedRequestIds.remove(requestId);
                                  } else {
                                    _expandedRequestIds.add(requestId);
                                  }
                                }),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: Text(_dateRange(item), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                                              const SizedBox(width: 8),
                                              Text('${days.length} day${days.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                            child: Text(displayStatus, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                                  ],
                                ),
                              ),
                              if (canCancel || canReturnEarly)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: statusColor,
                                        side: BorderSide(color: statusColor.withValues(alpha: 0.45)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: isActionInProgress ? null : () => canCancel ? _cancel(item) : _earlyReturn(item),
                                      icon: Icon(canCancel ? Icons.close_rounded : Icons.keyboard_return_rounded, size: 18),
                                      label: Text(isCancelling ? 'Cancelling...' : isRequestingEarlyReturn ? 'Submitting...' : canCancel ? 'Cancel request' : 'Return early'),
                                    ),
                                  ),
                                ),
                              if (isExpanded) ...[
                                const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Align(alignment: Alignment.centerLeft, child: Text('Reason', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
                                  const SizedBox(height: 4),
                                  Align(alignment: Alignment.centerLeft, child: Text(item['reason']?.toString() ?? '', style: Theme.of(context).textTheme.bodyMedium)),
                                  if (days.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...days.whereType<Map>().map((day) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(_formatDate(day['leave_date']))),
                                          Text(_dayStateLabel(day['state'].toString()), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    )),
                                  ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
