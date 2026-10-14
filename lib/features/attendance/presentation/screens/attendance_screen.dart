import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:sitepulse_engineer/features/attendance/presentation/bloc/stats/attendance_stats_bloc.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';

import 'package:sitepulse_engineer/shared/models/today_assignment.dart';
import 'package:sitepulse_engineer/core/storage/session_store.dart';

class AttendanceScreen extends StatelessWidget {
  final String sessionToken;

  const AttendanceScreen({super.key, required this.sessionToken});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceStatsBloc()
        ..add(LoadAttendanceStatsRequested(
            sessionToken: sessionToken,
            month: DateFormat('yyyy-MM').format(DateTime.now()))),
      child: _AttendanceView(sessionToken: sessionToken),
    );
  }
}

class _AttendanceView extends StatefulWidget {
  final String sessionToken;

  const _AttendanceView({required this.sessionToken});

  @override
  State<_AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<_AttendanceView> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    SessionStore.syncProfile().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
    context.read<AttendanceStatsBloc>().add(
          LoadAttendanceStatsRequested(
              sessionToken: widget.sessionToken,
              month: DateFormat('yyyy-MM').format(_selectedMonth)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        scrolledUnderElevation: 1,
        title: Text(
          'Attendance Overview',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocBuilder<AttendanceStatsBloc, AttendanceStatsState>(
          builder: (context, state) {
            if (state.status == AttendanceStatsStatus.loading ||
                state.status == AttendanceStatsStatus.initial) {
              return _buildShimmerLoading(context);
            }
            
            if (state.status == AttendanceStatsStatus.error) {
              return _buildErrorState(context, state.errorMessage ?? "An error occurred");
            }

            final data = state.data;
            if (data == null) {
              return _buildErrorState(context, "No data available");
            }

            final now = DateTime.now();
            final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
            final isPastMonth = _selectedMonth.isBefore(DateTime(now.year, now.month, 1));
            
            int daysToConsider;
            if (isCurrentMonth) {
              daysToConsider = now.day;
            } else if (isPastMonth) {
              daysToConsider = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
            } else {
              daysToConsider = 0;
            }
            
            final absentDays = (daysToConsider - data.totalPresentDays).clamp(0, 31);

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AttendanceStatsBloc>().add(
                      LoadAttendanceStatsRequested(
                          sessionToken: widget.sessionToken,
                          month: DateFormat('yyyy-MM').format(_selectedMonth)),
                    );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _AttendanceCalendarGrid(
                      items: data.items,
                      viewMonth: _selectedMonth,
                      weeklyOffDays: data.weeklyOffDays,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle(context, "Monthly Summary"),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: "Present",
                            value: "${data.totalPresentDays}",
                            subtitle: "Days",
                            icon: Icons.check_circle_rounded,
                            color: Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: "Absent",
                            value: "$absentDays",
                            subtitle: "Days",
                            icon: Icons.cancel_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: "Hours",
                            value: data.totalHours.toStringAsFixed(1),
                            subtitle: "Logged",
                            icon: Icons.access_time_filled_rounded,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final dateFormatter = DateFormat('EEEE, MMMM d');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateFormatter.format(now),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          "Your Attendance",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Track your monthly progress and timeline below.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }


  Widget _buildErrorState(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              "Failed to load attendance",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () {
                context.read<AttendanceStatsBloc>().add(
                      LoadAttendanceStatsRequested(
                          sessionToken: widget.sessionToken,
                          month: DateFormat('yyyy-MM').format(_selectedMonth)),
                    );
              },
              child: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ShimmerBox(width: 150, height: 24, borderRadius: 8),
        const SizedBox(height: 12),
        const ShimmerBox(width: 250, height: 32, borderRadius: 8),
        const SizedBox(height: 48),
        Row(
          children: const [
            Expanded(child: ShimmerBox(width: double.infinity, height: 130, borderRadius: 24)),
            SizedBox(width: 12),
            Expanded(child: ShimmerBox(width: double.infinity, height: 130, borderRadius: 24)),
            SizedBox(width: 12),
            Expanded(child: ShimmerBox(width: double.infinity, height: 130, borderRadius: 24)),
          ],
        ),
        const SizedBox(height: 40),
        const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
        const SizedBox(height: 40),
        const ShimmerBox(width: double.infinity, height: 80, borderRadius: 20),
        const SizedBox(height: 16),
        const ShimmerBox(width: double.infinity, height: 80, borderRadius: 20),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 380;
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
            SizedBox(height: isSmallScreen ? 12 : 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                      fontSize: isSmallScreen ? 20 : null,
                    ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                    fontSize: isSmallScreen ? 10 : null,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: isSmallScreen ? 9 : null,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCalendarGrid extends StatelessWidget {
  final List<dynamic> items;
  final DateTime viewMonth;
  final List<int>? weeklyOffDays;

  const _AttendanceCalendarGrid({
    required this.items,
    required this.viewMonth,
    this.weeklyOffDays,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(viewMonth.year, viewMonth.month);
    
    // Weekday: 1=Mon, 7=Sun. Offset calendar to start on Monday
    final firstWeekday = firstDayOfMonth.weekday;
    final offset = firstWeekday - 1; 

    final today = DateTime(now.year, now.month, now.day);

    // Map items by date string (yyyy-MM-dd)
    final itemsByDate = <String, List<dynamic>>{};
    for (final item in items) {
      final list = itemsByDate.putIfAbsent(item.workDate, () => []);
      list.add(item);
    }

    final cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final engineer = SessionStore.current?.engineer;
    final effectiveWeeklyOffs = weeklyOffDays ?? engineer?.weeklyOffDays ?? const [6];

    // Exact Admin Panel Color Palette (matches MonthlyAttendanceView.module.css)
    final Color adminPresentBg = isDark ? const Color(0xFF14532D).withValues(alpha: 0.35) : const Color(0xFFDCFCE7);
    final Color adminPresentText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15703D);
    final Color adminPresentBorder = isDark ? const Color(0xFF15703D).withValues(alpha: 0.6) : const Color(0xFF86EFAC);

    final Color adminAttentionBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFEDD5);
    final Color adminAttentionText = isDark ? const Color(0xFFFB923C) : const Color(0xFFA4470C);
    final Color adminAttentionBorder = isDark ? const Color(0xFFC2410C).withValues(alpha: 0.6) : const Color(0xFFFDBA74);

    final Color adminWeekOffBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.25) : const Color(0xFFFFF7ED);
    final Color adminWeekOffText = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    final Color adminWeekOffBorder = isDark ? const Color(0xFF9A3412).withValues(alpha: 0.5) : const Color(0xFFFED7AA);

    final Color adminAbsentBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEE2E2);
    final Color adminAbsentText = isDark ? const Color(0xFFF87171) : const Color(0xFFB4232D);
    final Color adminAbsentBorder = isDark ? const Color(0xFFB4232D).withValues(alpha: 0.6) : const Color(0xFFFCA5A5);

    final Color adminFutureBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F4F7);
    final Color adminFutureText = isDark ? Colors.white38 : const Color(0xFF98A2B3);

    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLegend(
          context,
          presentBg: adminPresentBg,
          presentText: adminPresentText,
          attentionBg: adminAttentionBg,
          attentionText: adminAttentionText,
          weekOffBg: adminWeekOffBg,
          weekOffText: adminWeekOffText,
          absentBg: adminAbsentBg,
          absentText: adminAbsentText,
          futureBg: adminFutureBg,
          futureText: adminFutureText,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.asMap().entries.map((entry) {
            final int dayIndex = entry.key; // 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
            final String dayName = entry.value;
            final bool isWeeklyOffHeader = effectiveWeeklyOffs.contains(dayIndex);
            return Expanded(
              child: Center(
                child: Text(
                  dayName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isWeeklyOffHeader ? adminWeekOffText : cs.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offset + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            if (index < offset) {
              return const SizedBox();
            }
            final day = index - offset + 1;
            final currentCellDate = DateTime(viewMonth.year, viewMonth.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(currentCellDate);
            final dayItems = itemsByDate[dateStr] ?? [];

            bool isFuture = currentCellDate.isAfter(today);
            final pyWeekday = currentCellDate.weekday - 1; // 0=Mon ... 6=Sun
            bool isWeeklyOff = effectiveWeeklyOffs.contains(pyWeekday);

            bool isOutOfRadiusItem(dynamic item) {
              if (item is EngineerTimesheetRow && item.isOutOfRadius == true) return true;
              final rem = (item.remarks ?? '').toString().toLowerCase();
              final mark = (item.mark ?? '').toString().toUpperCase();
              final status = (item.status ?? '').toString().toUpperCase();
              return rem.contains('out of radius') ||
                  rem.contains('out_of_radius') ||
                  rem.contains('outside radius') ||
                  rem.contains('outside allowed radius') ||
                  mark == 'OUT_OF_RADIUS' ||
                  mark == 'OOR' ||
                  status == 'OUT_OF_RADIUS';
            }

            bool isAutoClosedItem(dynamic item) {
              final rem = (item.remarks ?? '').toString().toUpperCase();
              final mark = (item.mark ?? '').toString().toUpperCase();
              final status = (item.status ?? '').toString().toUpperCase();
              return rem.startsWith('SYSTEM_AUTO_CLOSED') ||
                  rem.contains('AUTO_CLOSED') ||
                  rem.contains('AUTO-CLOSED') ||
                  rem.contains('SYSTEM AUTO-CLOSED') ||
                  rem.contains('CLOSED BY SYSTEM') ||
                  mark == 'AUTO_CLOSED' ||
                  mark == 'AC' ||
                  status == 'AUTO_CLOSED';
            }

            bool isIncompleteItem(dynamic item) {
              final mark = (item.mark ?? '').toString().toUpperCase();
              final status = (item.status ?? '').toString().toUpperCase();
              final isOngoing = item.punchInTime != null &&
                  item.punchInTime.year > 2000 &&
                  item.punchOutTime == null;
              return isOngoing ||
                  mark == 'INCOMPLETE' ||
                  mark == 'INC' ||
                  mark == 'MI' ||
                  mark == 'MO' ||
                  status == 'INCOMPLETE';
            }

            final bool hasOutOfRadius = dayItems.any(isOutOfRadiusItem);
            final bool hasAutoClosed = dayItems.any(isAutoClosedItem);
            final bool hasIncomplete = dayItems.any(isIncompleteItem);

            final bool isOrange = hasOutOfRadius || hasAutoClosed || hasIncomplete;

            final double totalHours = dayItems.fold(0.0, (sum, item) => sum + (item.totalHours as num));
            final bool isPresentMark = dayItems.any((item) => (item.mark ?? '').toString().toUpperCase() == 'P');
            final bool isPresent = !isOrange && dayItems.isNotEmpty && (isPresentMark || totalHours > 0);

            final bool isAbsentMark = dayItems.any((item) => (item.mark ?? '').toString().toUpperCase() == 'A');
            final bool isMissing = !isFuture && !isWeeklyOff && dayItems.isEmpty;
            final bool isAbsent = !isOrange && !isPresent && (isAbsentMark || isMissing);

            Color bgColor = adminFutureBg;
            Color textColor = adminFutureText;
            Color borderColor = Colors.transparent;
            Widget? extraInfo;

            if (isOrange) {
              bgColor = adminAttentionBg;
              textColor = adminAttentionText;
              borderColor = adminAttentionBorder;

              String label = 'Work';
              if (hasAutoClosed) {
                label = 'Auto';
              } else if (hasOutOfRadius) {
                label = 'Radius';
              } else if (hasIncomplete) {
                final isOngoing = dayItems.any((i) => i.punchInTime.year > 2000 && i.punchOutTime == null);
                label = isOngoing ? 'Work' : 'Inc';
              }

              extraInfo = Text(
                label,
                style: TextStyle(
                  color: adminAttentionText,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              );
            } else if (isPresent) {
              bgColor = adminPresentBg;
              textColor = adminPresentText;
              borderColor = adminPresentBorder;
              extraInfo = Text(
                totalHours > 0 ? '${totalHours.toStringAsFixed(1)}h' : 'P',
                style: TextStyle(
                  color: adminPresentText,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              );
            } else if (isAbsent) {
              bgColor = adminAbsentBg;
              textColor = adminAbsentText;
              borderColor = adminAbsentBorder;
              extraInfo = Text(
                'A',
                style: TextStyle(
                  color: adminAbsentText,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              );
            } else if (isFuture) {
              bgColor = adminFutureBg;
              textColor = adminFutureText;
              borderColor = Colors.transparent;
            } else if (isWeeklyOff) {
              bgColor = adminWeekOffBg;
              textColor = adminWeekOffText;
              borderColor = adminWeekOffBorder;
              extraInfo = Text(
                'WO',
                style: TextStyle(
                  color: adminWeekOffText,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              );
            }

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: dayItems.isEmpty ? null : () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (ctx) => _DailyDetailsBottomSheet(
                    date: currentCellDate,
                    items: dayItems,
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (extraInfo != null) ...[
                              const SizedBox(height: 2), // Slightly tighter spacing
                              extraInfo,
                            ]
                          ],
                        ),
                      ),
                    ),
                    if (dayItems.length > 1)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${dayItems.length}',
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegend(
    BuildContext context, {
    required Color presentBg,
    required Color presentText,
    required Color attentionBg,
    required Color attentionText,
    required Color weekOffBg,
    required Color weekOffText,
    required Color absentBg,
    required Color absentText,
    Color? futureBg,
    Color? futureText,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem('P', 'Present', presentBg, presentText),
          _buildLegendItem('P', 'Attention', attentionBg, attentionText),
          _buildLegendItem('WO', 'Week Off', weekOffBg, weekOffText),
          _buildLegendItem('A', 'Absent', absentBg, absentText),
          if (futureBg != null && futureText != null)
            _buildLegendItem('—', 'Future', futureBg, futureText),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String mark, String label, Color bg, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            mark,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _DailyDetailsBottomSheet extends StatelessWidget {
  final DateTime date;
  final List<dynamic> items;

  const _DailyDetailsBottomSheet({required this.date, required this.items});

  @override
  Widget build(BuildContext context) {
    String formatTime(DateTime dt) => DateFormat.jm().format(IstTime.toIst(dt));
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(date),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final isOngoing = item.punchInTime.year > 2000 && item.punchOutTime == null;

                final rem = (item.remarks ?? '').toString().toLowerCase();
                final mark = (item.mark ?? '').toString().toUpperCase();
                final status = (item.status ?? '').toString().toUpperCase();

                final isOutOfRadius = (item is EngineerTimesheetRow && item.isOutOfRadius == true) ||
                    rem.contains('out of radius') ||
                    rem.contains('out_of_radius') ||
                    rem.contains('outside radius') ||
                    mark == 'OUT_OF_RADIUS' ||
                    mark == 'OOR' ||
                    status == 'OUT_OF_RADIUS';

                final isAutoClosed = rem.toUpperCase().startsWith('SYSTEM_AUTO_CLOSED') ||
                    rem.toUpperCase().contains('AUTO_CLOSED') ||
                    rem.toUpperCase().contains('AUTO-CLOSED') ||
                    rem.toUpperCase().contains('CLOSED BY SYSTEM') ||
                    mark == 'AUTO_CLOSED' ||
                    mark == 'AC' ||
                    status == 'AUTO_CLOSED';

                final isIncomplete = isOngoing ||
                    mark == 'INCOMPLETE' ||
                    mark == 'INC' ||
                    mark == 'MI' ||
                    mark == 'MO' ||
                    status == 'INCOMPLETE';

                final bool isDark = Theme.of(context).brightness == Brightness.dark;
                final Color adminPresentBg = isDark ? const Color(0xFF14532D).withValues(alpha: 0.35) : const Color(0xFFDCFCE7);
                final Color adminPresentText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15703D);
                final Color adminAttentionBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFEDD5);
                final Color adminAttentionText = isDark ? const Color(0xFFFB923C) : const Color(0xFFA4470C);

                Color badgeBgColor;
                Color badgeTextColor;
                String badgeText;

                if (isAutoClosed) {
                  badgeBgColor = adminAttentionBg;
                  badgeTextColor = adminAttentionText;
                  badgeText = "Auto-Closed";
                } else if (isOutOfRadius) {
                  badgeBgColor = adminAttentionBg;
                  badgeTextColor = adminAttentionText;
                  badgeText = "Out of Radius";
                } else if (isIncomplete) {
                  badgeBgColor = adminAttentionBg;
                  badgeTextColor = adminAttentionText;
                  badgeText = isOngoing ? "Working" : "Incomplete";
                } else {
                  badgeBgColor = adminPresentBg;
                  badgeTextColor = adminPresentText;
                  badgeText = "${item.totalHours.toStringAsFixed(1)} hrs";
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.projectName,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: badgeTextColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.login_rounded, size: 14, color: Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            item.punchInTime.year > 2000 ? formatTime(item.punchInTime) : "--:--",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.logout_rounded, size: 14, color: cs.error),
                          const SizedBox(width: 4),
                          Text(
                            item.punchOutTime != null ? formatTime(item.punchOutTime) : "--:--",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

