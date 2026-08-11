import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({this.active = true, super.key});

  final bool active;

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  String? _selectedCode;
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LearningPathScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _scheduleLoadIfNeeded();
    }
  }

  void _scheduleLoadIfNeeded() {
    if (!widget.active || _loadScheduled) {
      return;
    }
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final viewModel = context.read<LearningPathViewModel>();
      if (viewModel.state == LearningPathState.initial) {
        viewModel.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }

    final l10n = context.watch<AppLanguageProvider>();
    final viewModel = context.watch<LearningPathViewModel>();
    return AppPage(
      children: [
        const LingoHeader(streak: null),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.translate('learning_path.title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSpacing.xxs.h),
            Text(
              l10n.translate('learning_path.subtitle', [
                viewModel.steps.length,
              ]),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
        _buildContent(context, l10n, viewModel),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLanguageProvider l10n,
    LearningPathViewModel viewModel,
  ) {
    return switch (viewModel.state) {
      LearningPathState.initial || LearningPathState.loading => KeyedSubtree(
        key: const Key('learning_path_loading'),
        child: loadingView(),
      ),
      LearningPathState.empty => _MessageCard(
        key: const Key('learning_path_empty'),
        icon: Icons.route_rounded,
        title: l10n.translate('learning_path.empty.title'),
        message: l10n.translate('learning_path.empty.message'),
      ),
      LearningPathState.error => _MessageCard(
        key: const Key('learning_path_error'),
        icon: Icons.cloud_off_rounded,
        title: l10n.translate('learning_path.error.title'),
        message: l10n.translate(
          viewModel.errorCode == 'network_unavailable' ||
                  viewModel.errorCode == 'request_timeout'
              ? 'learning_path.error.network'
              : 'learning_path.error.message',
        ),
        action: FilledButton.icon(
          key: const Key('learning_path_retry'),
          onPressed: viewModel.retry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.translate('common.retry')),
        ),
      ),
      LearningPathState.success => _PathList(
        steps: viewModel.steps,
        selectedCode: _selectedCode,
        onSelected: _openLesson,
      ),
    };
  }

  Future<void> _openLesson(String code) async {
    setState(() => _selectedCode = code);
    final repository = context.read<LessonRepository>();
    try {
      final lessons = await repository.today();
      final matches = lessons.where((lesson) => lesson.skillCode == code);
      if (!mounted) return;
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AppLanguageProvider>().translate(
                'learning_path.no_lesson',
              ),
            ),
          ),
        );
        return;
      }
      await context.push('/lesson/${matches.first.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AppLanguageProvider>().translate(
                'learning_path.open_error',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _PathList extends StatelessWidget {
  const _PathList({
    required this.steps,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<LearningPathStep> steps;
  final String? selectedCode;
  final Future<void> Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final firstIncomplete = steps.indexWhere((step) => step.mastery < 1);
    final firstRecommended = steps.indexWhere(
      (step) => step.mastery < 1 && step.reason == 'below_threshold',
    );
    final currentIndex = firstRecommended >= 0
        ? firstRecommended
        : firstIncomplete;
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _PathItem(
            step: steps[index],
            index: index,
            isLast: index == steps.length - 1,
            selected: selectedCode == steps[index].code,
            state: _pathStateFor(steps[index], index, currentIndex),
            onTap:
                _pathStateFor(steps[index], index, currentIndex) ==
                    _PathStepState.locked
                ? null
                : () => onSelected(steps[index].code),
          ),
      ],
    );
  }
}

enum _PathStepState { completed, current, unlocked, locked }

_PathStepState _pathStateFor(
  LearningPathStep step,
  int index,
  int currentIndex,
) {
  if (step.mastery >= 1) return _PathStepState.completed;
  if (index == currentIndex) return _PathStepState.current;
  if (step.reason == 'below_threshold') return _PathStepState.unlocked;
  return _PathStepState.locked;
}

class _PathItem extends StatelessWidget {
  const _PathItem({
    required this.step,
    required this.index,
    required this.isLast,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final LearningPathStep step;
  final int index;
  final bool isLast;
  final bool selected;
  final _PathStepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final localizedName = l10n.currentLanguage == AppLanguage.vi
        ? step.nameVi
        : step.name;
    final reasonKey = switch (step.reason) {
      'below_threshold' => 'learning_path.reason.below_threshold',
      'not_started' => 'learning_path.reason.not_started',
      _ => 'learning_path.reason.recommended',
    };

    final side = index.isEven ? Alignment.centerLeft : Alignment.centerRight;
    final current = state == _PathStepState.current;
    final isCompleted = state == _PathStepState.completed;
    final locked = state == _PathStepState.locked;
    final String statusText = l10n.translate(reasonKey);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color progressColor = scheme.primary;
    IconData iconData = Icons.play_arrow_rounded;
    Color iconBg = scheme.primary;
    Color iconColor = scheme.onPrimary;
    Color cardColor = scheme.surface;
    BorderSide borderSide = BorderSide(
      color: theme.colorScheme.primary,
      width: 1.5.w,
    );
    List<BoxShadow> shadow = [
      BoxShadow(
        color: theme.shadowColor.withValues(alpha: .08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];

    if (isCompleted) {
      progressColor = scheme.primary;
      iconData = Icons.check_rounded;
      iconBg = scheme.primaryContainer;
      iconColor = scheme.onPrimaryContainer;
    } else if (current) {
      progressColor = scheme.primary;
      iconData = Icons.play_arrow_rounded;
      iconBg = scheme.primaryContainer;
      iconColor = scheme.primary;
      borderSide = BorderSide(color: scheme.primary, width: 2.w);
      shadow = [
        BoxShadow(
          color: scheme.primary.withValues(alpha: .2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
    } else if (state == _PathStepState.unlocked) {
      progressColor = scheme.primary;
      iconData = Icons.psychology_rounded;
      iconBg = scheme.primaryContainer;
      iconColor = scheme.onPrimaryContainer;
    } else {
      iconData = Icons.lock_rounded;
      iconBg = scheme.surfaceContainerHigh;
      iconColor = scheme.onSurfaceVariant;
      cardColor = scheme.surfaceContainerLow;
      borderSide = BorderSide(color: scheme.outlineVariant, width: 1.w);
    }

    final stateName = state.name;
    final semanticsLabel = '$localizedName, ${step.cefr}, $statusText';

    return Semantics(
      key: Key('learning_path_state_${stateName}_${step.code}'),
      container: true,
      explicitChildNodes: true,
      button: true,
      enabled: !locked,
      selected: current || selected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Align(
            alignment: side,
            child: FractionallySizedBox(
              widthFactor: MediaQuery.sizeOf(context).width <= 340 ? .9 : .76,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: Key('learning_path_card_${step.code}'),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.xl.r),
                      border: Border.fromBorderSide(borderSide),
                      boxShadow: shadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl.r),
                      child: InkWell(
                        key: Key('learning_path_step_${step.code}'),
                        onTap: onTap,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.w,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: iconColor,
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizedName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          '${step.cefr} · $statusText',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                fontSize: 12.sp,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppSpacing.sm.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        999.r,
                                      ),
                                      child: LinearProgressIndicator(
                                        value: step.mastery.clamp(0.0, 1.0),
                                        minHeight: 6.h,
                                        backgroundColor:
                                            scheme.surfaceContainerHighest,
                                        color: progressColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm.w),
                                  Text(
                                    '${(step.mastery * 100).round()}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 11.sp,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (current)
                    Positioned(
                      top: -12.h,
                      left: 12.w,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            bottom: -4.h,
                            left: 16.w,
                            child: Transform.rotate(
                              angle: 3.14159 / 4,
                              child: Container(
                                width: 8.w,
                                height: 8.w,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm.w,
                              vertical: AppSpacing.xxs.h,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.md.r,
                              ),
                            ),
                            child: Text(
                              l10n
                                  .translate('learning_path.current_step')
                                  .toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.sp,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: 40.sp, color: Theme.of(context).colorScheme.primary),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20.sp),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14.sp,
            ),
          ),
          if (action != null) ...[SizedBox(height: AppSpacing.md.h), action!],
        ],
      ),
    );
  }
}
