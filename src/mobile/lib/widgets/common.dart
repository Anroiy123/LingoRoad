import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class AppPage extends StatelessWidget {
  const AppPage({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.margin.w,
          AppSpacing.md.h,
          AppSpacing.margin.w,
          112.h,
        ),
        children: _withSpacing(children),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> source) {
    return [
      for (var i = 0; i < source.length; i++) ...[
        source[i],
        if (i != source.length - 1) SizedBox(height: AppSpacing.lg.h),
      ],
    ];
  }
}

class LingoHeader extends StatelessWidget {
  const LingoHeader({this.streak, super.key});
  final int? streak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 16.r,
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(
            Icons.person_outline_rounded,
            size: 18.sp,
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(width: AppSpacing.xs.w),
        Text(
          'LingoRoad',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: scheme.primary,
            fontSize: 24.sp,
          ),
        ),
        if (streak != null) ...[
          const Spacer(),
          InkWell(
            key: const Key('header_streak'),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            onTap: () => context.push('/streak-details'),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xs.w),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 20.sp,
                    color: scheme.primary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '$streak',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum AppCardVariant { defaultSurface, outlined, tonal }

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.borderWidth = 1.5,
    this.borderRadius,
    this.variant = AppCardVariant.defaultSurface,
    super.key,
  });
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double? borderRadius;
  final AppCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        color ??
        switch (variant) {
          AppCardVariant.defaultSurface => theme.colorScheme.surface,
          AppCardVariant.outlined => theme.scaffoldBackgroundColor,
          AppCardVariant.tonal => theme.colorScheme.primaryContainer,
        };
    final cardBorderColor =
        borderColor ??
        switch (variant) {
          AppCardVariant.defaultSurface => theme.colorScheme.outlineVariant,
          AppCardVariant.outlined => theme.colorScheme.outline,
          AppCardVariant.tonal => theme.colorScheme.primaryContainer,
        };
    final shadowColor = isDark ? AppColorsDark.shadow : AppColors.shadow;

    return Container(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.lg.h,
          ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(
          (borderRadius ?? AppRadius.xl).r,
        ),
        border: Border.all(color: cardBorderColor, width: borderWidth.w),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppProgress extends StatelessWidget {
  const AppProgress({
    required this.value,
    this.height = 8,
    this.color,
    super.key,
  });
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(0, 1).toDouble();
    final percent = (safe * 100).round();
    String label;
    try {
      final l10n = context.watch<AppLanguageProvider>();
      label = l10n.translate('common.progress_percent', [percent]);
    } catch (_) {
      label = 'Tiến độ $percent phần trăm';
    }
    return Semantics(
      label: label,
      value: '$percent%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999.r),
        child: LinearProgressIndicator(
          value: safe,
          minHeight: height.h,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22.sp),
  );
}

class MetricRow extends StatelessWidget {
  const MetricRow({required this.label, required this.value, super.key});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 14.sp),
              ),
            ),
            Text(
              '$value%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        AppProgress(value: value / 100),
      ],
    );
  }
}

Widget loadingView({Key? key, String? label}) => Builder(
  builder: (context) => Semantics(
    key: key,
    liveRegion: true,
    label:
        label ??
        context.read<AppLanguageProvider>().translate('common.loading'),
    child: ExcludeSemantics(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 64.w, vertical: 64.h),
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ),
  ),
);
