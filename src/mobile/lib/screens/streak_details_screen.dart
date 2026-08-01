import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

enum DayStatus { none, active, freeze, today }

class StreakDetailsScreen extends StatefulWidget {
  const StreakDetailsScreen({super.key});

  @override
  State<StreakDetailsScreen> createState() => _StreakDetailsScreenState();
}

class _StreakDetailsScreenState extends State<StreakDetailsScreen> {
  DateTime _currentMonth = DateTime(2025, 10); // Start at October 2025 to match original mock

  DayStatus _getDayStatus(DateTime date) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate.isAtSameMomentAs(todayDate)) {
      return DayStatus.today;
    }
    if (targetDate.isAfter(todayDate)) {
      return DayStatus.none;
    }

    // Preserve mock status exactly for October 2025 (as in original mockup)
    if (date.year == 2025 && date.month == 10) {
      if (date.day == 12) {
        return DayStatus.today;
      }
      if (date.day == 5) {
        return DayStatus.freeze;
      }
      if (date.day >= 3 && date.day <= 11) {
        return DayStatus.active;
      }
      return DayStatus.none;
    }

    // Generate realistic streaks deterministically for other months/years
    final day = date.day;
    if (day % 15 == 5) {
      return DayStatus.freeze;
    }
    if (day % 7 == 0 || day % 11 == 0) {
      return DayStatus.none;
    }
    return DayStatus.active;
  }

  String _getMonthName(DateTime date, AppLanguageProvider l10n) {
    final monthKeys = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];
    final key = monthKeys[date.month - 1];
    final monthName = l10n.translate('streak.months.$key');
    return '$monthName ${date.year}';
  }

  List<Widget> _buildCalendarRows(AppLanguageProvider l10n) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;

    // 1st of the month
    final firstDay = DateTime(year, month, 1);
    // Weekday of the first day: 1 = Mon, 7 = Sun
    final firstWeekday = firstDay.weekday;
    // Number of empty offset days (Mon is index 0)
    final offset = firstWeekday - 1;

    // Total days in the month
    final totalDays = DateTime(year, month + 1, 0).day;

    final List<int?> days = [];
    // Add offsets
    for (var i = 0; i < offset; i++) {
      days.add(null);
    }
    // Add actual days
    for (var i = 1; i <= totalDays; i++) {
      days.add(i);
    }
    // Pad the end to complete the last row
    while (days.length % 7 != 0) {
      days.add(null);
    }

    final List<Widget> rows = [];
    for (var i = 0; i < days.length; i += 7) {
      final chunk = days.sublist(i, i + 7);
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            children: chunk.map((day) {
              if (day == null) {
                return _buildDayCell(null, l10n);
              }
              final date = DateTime(year, month, day);
              final status = _getDayStatus(date);
              
              return _buildDayCell(
                day,
                l10n,
                isActive: status == DayStatus.active,
                isFreeze: status == DayStatus.freeze,
                isToday: status == DayStatus.today,
              );
            }).toList(),
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final l10n = context.watch<AppLanguageProvider>();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Custom TopAppBar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40.w,
                          height: 40.h,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 24.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        l10n.translate('streak.title'),
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 40.w), // Balance spacer
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
                    child: Column(
                      children: [
                        // Main Streak Card
                        StreakCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 64.sp,
                                color: AppColors.cta,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                l10n.translate('streak.days_count', [12]),
                                style: TextStyle(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                l10n.translate('streak.current_streak'),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Stats Double Row
                        Row(
                          children: [
                            // Record Card
                            Expanded(
                              child: StreakCard(
                                padding: EdgeInsets.all(16.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32.w,
                                      height: 32.h,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.surfaceLow,
                                      ),
                                      child: Icon(
                                        Icons.emoji_events_rounded,
                                        color: AppColors.cta,
                                        size: 18.sp,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      l10n.translate('streak.record_title'),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      l10n.translate('streak.record_value', [18]),
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            // Streak Freeze Card
                            Expanded(
                              child: StreakCard(
                                padding: EdgeInsets.all(16.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 32.w,
                                          height: 32.h,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.surfaceLow,
                                          ),
                                          child: Icon(
                                            Icons.ac_unit_rounded,
                                            color: Colors.blue,
                                            size: 18.sp,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.translate('common.not_implemented'),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            l10n.translate('streak.buy'),
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.cta,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      l10n.translate('streak.protect_title'),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      l10n.translate('streak.protect_value', [1]),
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        // Calendar Section
                        StreakCard(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Month header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _getMonthName(_currentMonth, l10n),
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _currentMonth = DateTime(
                                              _currentMonth.year,
                                              _currentMonth.month - 1,
                                            );
                                          });
                                        },
                                        child: Icon(
                                          Icons.chevron_left_rounded,
                                          color: AppColors.textSecondary,
                                          size: 28.sp,
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _currentMonth = DateTime(
                                              _currentMonth.year,
                                              _currentMonth.month + 1,
                                            );
                                          });
                                        },
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.textSecondary,
                                          size: 28.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),
                              // Weekdays Header Row
                              Row(
                                children: [
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.mon')),
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.tue')),
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.wed')),
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.thu')),
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.fri')),
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.sat')),
                                  _buildWeekdayHeader(l10n.translate('streak.weekdays.sun')),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              // Dynamic Days List Grid
                              Column(
                                children: _buildCalendarRows(l10n),
                              ),
                              // Divider
                              SizedBox(height: 16.h),
                              Divider(
                                color: AppColors.surfaceHigh,
                                thickness: 1.w,
                              ),
                              SizedBox(height: 24.h),
                              // Legend list
                              Column(
                                children: [
                                  _buildLegendRow(
                                    icon: Icons.local_fire_department_rounded,
                                    iconColor: AppColors.cta,
                                    circleColor: AppColors.primaryFixed,
                                    text: l10n.translate('streak.legend.learned'),
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildLegendRow(
                                    icon: Icons.ac_unit_rounded,
                                    iconColor: Colors.blue,
                                    circleColor: Colors.blue.withValues(alpha: 0.15),
                                    text: l10n.translate('streak.legend.freeze'),
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildLegendRow(
                                    icon: Icons.close_rounded,
                                    iconColor: AppColors.textSecondary,
                                    circleColor: AppColors.surfaceLow,
                                    text: l10n.translate('streak.legend.missed'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeader(String text) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    int? day,
    AppLanguageProvider l10n, {
    bool isActive = false,
    bool isFreeze = false,
    bool isToday = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDayCircle(day, isActive, isFreeze, isToday),
          if (isToday) ...[
            SizedBox(height: 4.h),
            Text(
              l10n.translate('streak.today'),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.cta,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            SizedBox(height: 14.h), // align days nicely
        ],
      ),
    );
  }

  Widget _buildDayCircle(
    int? day,
    bool isActive,
    bool isFreeze,
    bool isToday,
  ) {
    if (day == null) {
      return SizedBox(width: 40.w, height: 40.h);
    }

    if (isToday) {
      return Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cta, width: 2.w),
          color: AppColors.background,
        ),
        padding: EdgeInsets.all(2.w),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cta,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 18.sp,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isActive) {
      return Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryFixed.withValues(alpha: 0.4),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 24.sp,
                color: AppColors.cta.withValues(alpha: 0.2),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isFreeze) {
      return Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withValues(alpha: 0.15),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.ac_unit_rounded,
                size: 24.sp,
                color: Colors.blue.withValues(alpha: 0.2),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Normal day
    return Container(
      width: 40.w,
      height: 40.h,
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLegendRow({
    required IconData icon,
    required Color iconColor,
    required Color circleColor,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleColor,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18.sp,
          ),
        ),
        SizedBox(width: 16.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class StreakCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double scaleOnPressed;
  final BorderRadius? borderRadius;

  const StreakCard({
    required this.child,
    this.onTap,
    this.color,
    this.padding,
    this.scaleOnPressed = 0.98,
    this.borderRadius,
    super.key,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() => _scale = widget.scaleOnPressed);
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _scale = 1.0);
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          setState(() => _scale = 1.0);
        }
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: widget.padding ?? EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: widget.color ?? AppColors.surface,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.surfaceHigh),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
