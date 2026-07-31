import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('learning_path.title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              l10n.translate(
                'learning_path.subtitle',
                [viewModel.steps.length],
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
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
          onSelected: (code) => setState(() => _selectedCode = code),
        ),
    };
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
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 32,
          bottom: 32,
          child: Container(width: 3, color: AppColors.border),
        ),
        Column(
          children: [
            for (var index = 0; index < steps.length; index++)
              _PathItem(
                step: steps[index],
                current: index == 0,
                side:
                    index.isEven ? Alignment.centerLeft : Alignment.centerRight,
                selected: selectedCode == steps[index].code,
                onTap: () => onSelected(steps[index].code),
              ),
          ],
        ),
      ],
    );
  }
}

class _PathItem extends StatelessWidget {
  const _PathItem({
    required this.step,
    required this.current,
    required this.side,
    required this.selected,
    required this.onTap,
  });

  final LearningPathStep step;
  final bool current;
  final Alignment side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final localizedName =
        l10n.currentLanguage == AppLanguage.vi ? step.nameVi : step.name;
    final reasonKey = switch (step.reason) {
      'below_threshold' => 'learning_path.reason.below_threshold',
      'not_started' => 'learning_path.reason.not_started',
      _ => 'learning_path.reason.recommended',
    };

    return Align(
      alignment: side,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * .72,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: current ? AppColors.primaryFixed : AppColors.surface,
            child: InkWell(
              key: Key('learning_path_step_${step.code}'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            current ? AppColors.primary : AppColors.surfaceHigh,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.primary, width: 3)
                            : null,
                      ),
                      child: Icon(
                        current
                            ? Icons.flight_takeoff_rounded
                            : Icons.route_rounded,
                        color: current ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (current)
                            Text(
                              l10n.translate('learning_path.current_step'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          Text(
                            localizedName,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            '${step.cefr} · ${l10n.translate(reasonKey)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppProgress(value: step.mastery),
                        ],
                      ),
                    ),
                  ],
                ),
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
          Icon(icon, size: 40, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
