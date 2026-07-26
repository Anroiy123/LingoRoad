import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

class AppPage extends StatelessWidget {
  const AppPage({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.md,
          AppSpacing.margin,
          112,
        ),
        children: _withSpacing(children),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> source) {
    return [
      for (var i = 0; i < source.length; i++) ...[
        source[i],
        if (i != source.length - 1) const SizedBox(height: AppSpacing.lg),
      ],
    ];
  }
}

class LingoHeader extends StatelessWidget {
  const LingoHeader({this.streak = 12, super.key});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceDisabled,
          child: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'lingoRoad',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
        ),
        const Spacer(),
        const Icon(
          Icons.local_fire_department_rounded,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 4),
        Text(
          '$streak',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.surfaceHigh),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
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
    this.color = AppColors.primary,
    super.key,
  });
  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(0, 1).toDouble();
    return Semantics(
      label: 'Tiến độ ${(safe * 100).round()} phần trăm',
      value: '${(safe * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: safe,
          minHeight: height,
          backgroundColor: AppColors.surfaceHigh,
          color: color,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
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
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '$value%',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AppProgress(value: value / 100),
      ],
    );
  }
}

Widget loadingView() => const Center(
      child: Padding(
        padding: EdgeInsets.all(64),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
