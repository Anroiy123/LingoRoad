import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({this.active = true, super.key});
  final bool active;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _scheduled = false;
  bool _showBack = false;
  final CardSwiperController _swiperController = CardSwiperController();
  int? _pendingRating;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _scheduled = false;
      _schedule();
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  void _schedule() {
    if (!widget.active || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<ReviewViewModel>();
      if (vm.state == ReviewState.initial ||
          vm.state == ReviewState.complete ||
          vm.state == ReviewState.empty) {
        vm.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final vm = context.watch<ReviewViewModel>();
    final l = context.watch<AppLanguageProvider>();
    return AppPage(children: [
      const LingoHeader(streak: null),
      Text(l.translate('review.title'),
          style: Theme.of(context)
               .textTheme
               .headlineMedium
               ?.copyWith(fontSize: 28.sp)),
      _content(vm, l)
    ]);
  }

  Widget _content(ReviewViewModel vm, AppLanguageProvider l) {
    if (vm.state == ReviewState.initial || vm.state == ReviewState.loading) {
      return loadingView();
    }
    if (vm.state == ReviewState.error) {
      return _message(
          Icons.cloud_off_rounded,
          l.translate('review.error.title'),
          l.translate('review.error.message'),
          vm.load);
    }
    if (vm.state == ReviewState.empty) {
      return _message(Icons.inbox_outlined, l.translate('review.empty.title'),
          l.translate('review.empty.message'), vm.load);
    }
    if (vm.state == ReviewState.complete) {
      return _message(
          Icons.check_circle_outline,
          l.translate('review.complete.title'),
          l.translate('review.complete.subtitle'),
          vm.load);
    }

    return Column(children: [
      Text(l.translate('review.remaining', [vm.remaining]),
          style: Theme.of(context).textTheme.bodyMedium),
      SizedBox(height: AppSpacing.md.h),
      SizedBox(
        height: 320.h,
        child: CardSwiper(
          key: ValueKey(vm.cards),
          controller: _swiperController,
          cardsCount: vm.cards.length,
          initialIndex: vm.currentIndex,
          allowedSwipeDirection:
              const AllowedSwipeDirection.only(left: true, right: true),
          isLoop: false,
          onSwipe: (previousIndex, currentIndex, direction) =>
              _onSwipe(previousIndex, currentIndex, direction, vm),
          cardBuilder: (context, index, percentX, percentY) {
            final card = vm.cards[index];
            return FlipCard(
              fill: Fill.fillBack,
              flipOnTouch: !vm.gradePending,
              onFlip: () {
                if (mounted) {
                  setState(() {
                    _showBack = true;
                  });
                }
              },
              front: AppCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg.w),
                    child: Text(
                      card.front,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 30.sp,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ),
              back: AppCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg.w),
                    child: Text(
                      card.back,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 30.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      SizedBox(height: AppSpacing.md.h),
      if (!_showBack)
        Text(l.translate('review.tap_to_reveal'))
      else
        Row(children: [
          _grade(l, 'forgot', 1, AppColors.error, vm),
          _grade(l, 'hard', 2, AppColors.warning, vm),
          _grade(l, 'good', 3, AppColors.success, vm),
          _grade(l, 'easy', 4, AppColors.primary, vm)
        ]),
      if (vm.gradePending)
        const Padding(
            padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
      if (vm.errorCode != null && !vm.gradePending)
        Text(l.translate('review.grade_error'),
            style: TextStyle(color: AppColors.error)),
    ]);
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
    ReviewViewModel vm,
  ) {
    final rating =
        _pendingRating ?? (direction == CardSwiperDirection.left ? 1 : 3);
    _pendingRating = null;

    vm.grade(rating).then((_) {
      if (mounted) {
        setState(() {
          _showBack = false;
        });
      }
    }).catchError((_) {
      _swiperController.undo();
    });

    return true;
  }

  Widget _grade(AppLanguageProvider l, String key, int value, Color color,
          ReviewViewModel vm) =>
      Expanded(
          child: Padding(
              padding: EdgeInsets.all(2.w),
              child: OutlinedButton(
                  onPressed:
                      vm.gradePending ? null : () => _gradeCard(vm, value),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: color, side: BorderSide(color: color)),
                  child: Text(l.translate('review.rating.$key')))));

  void _gradeCard(ReviewViewModel vm, int rating) {
    _pendingRating = rating;
    if (rating == 1 || rating == 2) {
      _swiperController.swipe(CardSwiperDirection.left);
    } else {
      _swiperController.swipe(CardSwiperDirection.right);
    }
  }

  Widget _message(
          IconData icon, String title, String message, VoidCallback action) =>
      AppCard(
          child: Column(children: [
        Icon(icon, size: 42.sp, color: AppColors.primary),
        SizedBox(height: AppSpacing.sm.h),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: AppSpacing.xs.h),
        Text(message, textAlign: TextAlign.center),
        SizedBox(height: AppSpacing.md.h),
        FilledButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
                context.read<AppLanguageProvider>().translate('common.retry')))
      ]));
}
