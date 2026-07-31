import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
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
  late final CardSwiperController _swiperController;
  int _index = 0;
  int _sessionKey = 0;
  bool _flipped = false;
  bool _soundPressed = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _swiperController = CardSwiperController();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

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
          if (_isComplete) return _complete(context, l10n);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.margin.w,
              AppSpacing.md.h,
              AppSpacing.margin.w,
              AppSpacing.lg.h,
            ),
            child: Column(
              children: [
                const LingoHeader(),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  l10n.translate('review.title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28.sp),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  l10n.translate('review.remaining', [cards.length - _index]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                AppProgress(value: _index / cards.length),
                SizedBox(height: AppSpacing.xl.h),
                Expanded(
                  child: CardSwiper(
                    key: ValueKey(_sessionKey),
                    controller: _swiperController,
                    cardsCount: cards.length,
                    initialIndex: _index,
                    isLoop: false,
                    allowedSwipeDirection: const AllowedSwipeDirection.only(
                      left: true,
                      right: true,
                      up: false,
                      down: false,
                    ),
                    onSwipe: (previousIndex, currentIndex, direction) {
                      setState(() {
                        _index = currentIndex ?? cards.length;
                        _flipped = false;
                        _soundPressed = false;
                      });
                      return true;
                    },
                    onEnd: () {
                      setState(() {
                        _isComplete = true;
                      });
                    },
                    cardBuilder: (context, index, percentX, percentY) {
                      final card = cards[index];
                      return FlipCard(
                        direction: FlipDirection.HORIZONTAL,
                        flipOnTouch: true,
                        onFlipDone: (isFront) {
                          setState(() {
                            _flipped = !isFront;
                          });
                        },
                        front: _buildCardFront(card, l10n),
                        back: _buildCardBack(card, l10n),
                      );
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                if (_flipped)
                  Row(
                    children: [
                      _rating(
                        label: l10n.translate('review.rating.forgot'),
                        color: AppColors.error,
                        direction: CardSwiperDirection.left,
                      ),
                      _rating(
                        label: l10n.translate('review.rating.hard'),
                        color: AppColors.warning,
                        direction: CardSwiperDirection.left,
                      ),
                      _rating(
                        label: l10n.translate('review.rating.good'),
                        color: AppColors.success,
                        direction: CardSwiperDirection.right,
                      ),
                      _rating(
                        label: l10n.translate('review.rating.easy'),
                        color: AppColors.primary,
                        direction: CardSwiperDirection.right,
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                    child: Text(
                      l10n.translate('review.hint'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
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

  Widget _buildCardFront(ReviewCardData card, AppLanguageProvider l10n) {
    return AppCard(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: l10n.translate('review.audio_tooltip'),
              onPressed: () => setState(() => _soundPressed = true),
              icon: Icon(
                Icons.volume_up_outlined,
                color: AppColors.textSecondary,
                size: 24.sp,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDisabled,
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                  child: Text(
                    l10n.translate(card.category),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  l10n.translate(card.word),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32.sp),
                ),
                SizedBox(height: AppSpacing.md.h),
                Text(
                  l10n.translate('review.tap_to_reveal'),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: AppColors.muted,
                        fontSize: 12.sp,
                      ),
                ),
                if (_soundPressed) ...[
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    l10n.translate('review.audio_pressed'),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(ReviewCardData card, AppLanguageProvider l10n) {
    return AppCard(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: l10n.translate('review.audio_tooltip'),
              onPressed: () => setState(() => _soundPressed = true),
              icon: Icon(
                Icons.volume_up_outlined,
                color: AppColors.textSecondary,
                size: 24.sp,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDisabled,
                    borderRadius: BorderRadius.circular(99.r),
                  ),
                  child: Text(
                    l10n.translate(card.category),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  l10n.translate(card.meaning),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32.sp),
                ),
                SizedBox(height: AppSpacing.md.h),
                Container(
                  height: 1.h,
                  width: 200.w,
                  color: AppColors.border,
                ),
                SizedBox(height: AppSpacing.md.h),
                Text(
                  l10n.translate(card.example),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                ),
                if (_soundPressed) ...[
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    l10n.translate('review.audio_pressed'),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rating({
    required String label,
    required Color color,
    required CardSwiperDirection direction,
  }) =>
      Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 3.w),
          child: OutlinedButton(
            onPressed: () => _swiperController.swipe(direction),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              minimumSize: Size(0, 48.h),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
        ),
      );

  Widget _complete(BuildContext context, AppLanguageProvider l10n) => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.margin.w, vertical: AppSpacing.margin.h),
        child: Column(
          children: [
            const LingoHeader(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 38.r,
                    backgroundColor: AppColors.primaryFixed,
                    child: Icon(
                      Icons.restart_alt_rounded,
                      size: 34.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  Text(
                    l10n.translate('review.complete.title'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28.sp),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  Text(
                    l10n.translate('review.complete.subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                        ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  FilledButton(
                    onPressed: () => setState(() {
                      _index = 0;
                      _isComplete = false;
                      _sessionKey++;
                      _flipped = false;
                      _soundPressed = false;
                    }),
                    child: Text(
                      l10n.translate('review.complete.restart'),
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

