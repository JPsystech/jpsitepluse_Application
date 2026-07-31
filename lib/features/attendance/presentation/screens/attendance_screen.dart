import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:sitepulse_engineer/features/attendance/presentation/bloc/stats/attendance_stats_bloc.dart';
import 'package:sitepulse_engineer/core/theme/app_colors_extension.dart';
import 'package:sitepulse_engineer/core/utils/ist_time.dart';
import 'package:sitepulse_engineer/shared/widgets/shimmer_box.dart';

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

  const _AttendanceCalendarGrid({required this.items, required this.viewMonth});

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
    final successColor = Theme.of(context).extension<AppColorsExtension>()?.success ?? const Color(0xFF10B981);
    final errorColor = cs.error;
    final greyColor = cs.surfaceContainerHighest;

    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((day) => Expanded(
            child: Center(
              child: Text(
                day,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )).toList(),
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
            bool isSunday = currentCellDate.weekday == DateTime.sunday;
            
            bool isOngoing = dayItems.any((item) => item.punchInTime.year > 2000 && item.punchOutTime == null);
            double totalHours = dayItems.fold(0.0, (sum, item) => sum + (item.totalHours as num));
            bool isPresent = dayItems.isNotEmpty && (dayItems.any((item) => item.mark == 'P') || totalHours > 0) && !isOngoing;
            bool isAbsent = dayItems.any((item) => item.mark == 'A');
            
            // Mark red if it's a past weekday and there's no punch log
            bool isMissing = !isFuture && !isPresent && !isOngoing && !isSunday; 
            
            Color bgColor = greyColor.withValues(alpha: 0.3);
            Color textColor = cs.onSurfaceVariant;
            Widget? extraInfo;
            
            if (isOngoing) {
              final warningColor = Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B);
              bgColor = warningColor.withValues(alpha: 0.15);
              textColor = warningColor.withAlpha(220);
              extraInfo = Text(
                'Work',
                style: TextStyle(
                  color: warningColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              );
            } else if (isPresent) {
              bgColor = successColor.withValues(alpha: 0.15);
              textColor = successColor.withAlpha(220);
              extraInfo = Text(
                '${totalHours.toStringAsFixed(1)}h',
                style: TextStyle(
                  color: successColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              );
            } else if (isAbsent || isMissing) {
              bgColor = errorColor.withValues(alpha: 0.1);
              textColor = errorColor;
              extraInfo = Text(
                'Abs',
                style: TextStyle(
                  color: errorColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              );
            } else if (isFuture) {
              bgColor = greyColor.withValues(alpha: 0.2);
              textColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
            } else if (isSunday) {
              bgColor = greyColor.withValues(alpha: 0.4);
              textColor = cs.onSurfaceVariant.withValues(alpha: 0.7);
              extraInfo = Text(
                'Off',
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
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
                    color: isOngoing 
                        ? (Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B)).withValues(alpha: 0.3)
                        : isPresent ? successColor.withValues(alpha: 0.3) 
                        : (isAbsent || isMissing ? errorColor.withValues(alpha: 0.3) : Colors.transparent),
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
                              color: isOngoing 
                                  ? (Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B)).withValues(alpha: 0.15)
                                  : cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOngoing ? "Working" : "${item.totalHours.toStringAsFixed(1)} hrs",
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isOngoing 
                                        ? (Theme.of(context).extension<AppColorsExtension>()?.warning ?? const Color(0xFFF59E0B))
                                        : cs.primary,
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

