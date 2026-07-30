import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/data/mock_repository.dart';
import 'package:lingoroad_mobile/models/models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});
  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  late final Future<List<PathNode>> _path = const MockRepository().path();
  String _selected = 'learning_path.lessons.lesson_5';

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return AppPage(
      children: [
        const LingoHeader(),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('learning_path.title', ['B1']),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    l10n.translate('learning_path.subtitle', [5, l10n.translate('learning_path.stage_title')]),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.primary,
            ),
            Text(
              ' 12',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        FutureBuilder<List<PathNode>>(
          future: _path,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return loadingView();
            return Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: AppColors.border),
                ),
                Column(
                  children: [
                    for (final node in snapshot.data!)
                      _PathItem(
                        node: node,
                        selected: _selected == node.title,
                        onTap: () => setState(() => _selected = node.title),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PathItem extends StatelessWidget {
  const _PathItem({
    required this.node,
    required this.selected,
    required this.onTap,
  });
  final PathNode node;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final locked = node.status == 'locked';
    final complete = node.status == 'complete';
    final current = node.status == 'current';
    final align = node.side == 'left'
        ? Alignment.centerLeft
        : node.side == 'right'
            ? Alignment.centerRight
            : Alignment.center;
    return SizedBox(
      height: current ? 166 : 112,
      child: Align(
        alignment: align,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: node.side == 'center' ? 0 : 72,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.translate('learning_path.current_lesson'),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              if (current) const SizedBox(height: 4),
              InkWell(
                onTap: locked ? null : onTap,
                borderRadius: BorderRadius.circular(99),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: current ? 64 : 48,
                  height: current ? 64 : 48,
                  decoration: BoxDecoration(
                    color: locked ? AppColors.surfaceHigh : AppColors.primary,
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(color: AppColors.primaryFixed, width: 5)
                        : null,
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: AppColors.primaryShadow,
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    locked
                        ? Icons.lock_rounded
                        : complete
                            ? Icons.check_rounded
                            : Icons.flight_takeoff_rounded,
                    color: locked ? AppColors.muted : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.primary,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.translate(node.title),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                      Text(
                        l10n.translate(node.subtitle),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                )
              else
                Text(
                  complete ? '+${node.xp} XP' : l10n.translate(node.title),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: locked ? AppColors.muted : AppColors.primary,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
