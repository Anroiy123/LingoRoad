import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/data/mock_repository.dart';
import 'package:lingoroad_mobile/models/models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final Future<List<ReviewCardData>> _future =
      const MockRepository().reviews();
  int _index = 0;
  bool _flipped = false;
  bool _soundPressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<ReviewCardData>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return loadingView();
          final cards = snapshot.data!;
          if (_index >= cards.length) return _complete(context, l10n);
          final card = cards[_index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.margin,
              AppSpacing.md,
              AppSpacing.margin,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                const LingoHeader(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.translate('review.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.translate('review.remaining', [cards.length - _index]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppProgress(value: _index / cards.length),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.translate('review.flip_card_semantics'),
                    child: InkWell(
                      onTap: () => setState(() => _flipped = !_flipped),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: AppCard(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                tooltip: l10n.translate('review.audio_tooltip'),
                                onPressed: () =>
                                    setState(() => _soundPressed = true),
                                icon: const Icon(
                                  Icons.volume_up_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceDisabled,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      l10n.translate(card.category),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    _flipped ? l10n.translate(card.meaning) : l10n.translate(card.word),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  if (_flipped) ...[
                                    Container(
                                      height: 1,
                                      width: 200,
                                      color: AppColors.border,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      l10n.translate(card.example),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ] else
                                    Text(
                                      l10n.translate('review.tap_to_reveal'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: AppColors.muted),
                                    ),
                                  if (_soundPressed) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      l10n.translate('review.audio_pressed'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: AppColors.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_flipped)
                  Row(
                    children: [
                      _rating(l10n.translate('review.rating.forgot'), AppColors.error),
                      _rating(l10n.translate('review.rating.hard'), AppColors.warning),
                      _rating(l10n.translate('review.rating.good'), AppColors.success),
                      _rating(l10n.translate('review.rating.easy'), AppColors.primary),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      l10n.translate('review.hint'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
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

  Widget _rating(String label, Color color) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton(
            onPressed: () => setState(() {
              _index++;
              _flipped = false;
              _soundPressed = false;
            }),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              minimumSize: const Size(0, 48),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(label),
          ),
        ),
      );

  Widget _complete(BuildContext context, AppLanguageProvider l10n) => Padding(
        padding: const EdgeInsets.all(AppSpacing.margin),
        child: Column(
          children: [
            const LingoHeader(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.primaryFixed,
                    child: Icon(
                      Icons.restart_alt_rounded,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.translate('review.complete.title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.translate('review.complete.subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => setState(() => _index = 0),
                    child: Text(l10n.translate('review.complete.restart')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
