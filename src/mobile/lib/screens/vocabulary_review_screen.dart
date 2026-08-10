import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class VocabularyReviewScreen extends StatefulWidget {
  const VocabularyReviewScreen({super.key});

  @override
  State<VocabularyReviewScreen> createState() => _VocabularyReviewScreenState();
}

class _VocabularyReviewScreenState extends State<VocabularyReviewScreen> {
  bool _loadScheduled = false;
  bool _showBack = false;
  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<ReviewViewModel>();
    if (!_loadScheduled) {
      _loadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          vm.load();
        }
      });
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    final l = context.watch<AppLanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(l.translate('review.title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.margin.w,
            AppSpacing.md.h,
            AppSpacing.margin.w,
            AppSpacing.lg.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _content(vm, l)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(ReviewViewModel vm, AppLanguageProvider l) {
    if (vm.state == ReviewState.initial || vm.state == ReviewState.loading) {
      return KeyedSubtree(
        key: const Key('review_loading'),
        child: loadingView(),
      );
    }
    if (vm.state == ReviewState.error) {
      return _message(
        key: const Key('review_error'),
        icon: Icons.cloud_off_rounded,
        title: l.translate('review.error.title'),
        message: l.translate('review.error.message'),
        action: vm.load,
        retryKey: const Key('review_retry'),
      );
    }
    if (vm.state == ReviewState.empty) {
      return _message(
        key: const Key('review_empty'),
        icon: Icons.inbox_outlined,
        title: l.translate('review.empty.title'),
        message: l.translate('review.empty.message'),
        action: vm.load,
      );
    }
    if (vm.state == ReviewState.complete) {
      return _message(
        key: const Key('review_complete'),
        icon: Icons.check_circle_outline,
        title: l.translate('review.complete.title'),
        message: l.translate('review.complete.subtitle'),
        action: vm.load,
      );
    }

    return Column(
      children: [
        Text(
          l.translate('review.remaining', [vm.remaining]),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: AppSpacing.md.h),
        Expanded(
          child: CardSwiper(
            key: ValueKey(vm.cards),
            controller: _swiperController,
            cardsCount: vm.cards.length,
            numberOfCardsDisplayed: vm.cards.length == 1 ? 1 : 2,
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
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20.sp,
                              color: AppColors.primary,
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
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: FilledButton.icon(
              key: const Key('review_mark_learned_button'),
              onPressed: vm.gradePending ? null : () => _markLearned(vm),
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                l.translate('review.mark_learned'),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ),
        if (vm.gradePending)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        if (vm.errorCode != null && !vm.gradePending)
          Text(
            l.translate('review.grade_error'),
            style: const TextStyle(color: AppColors.error),
          ),
      ],
    );
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
    ReviewViewModel vm,
  ) {
    vm.grade().then((_) {
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

  void _markLearned(ReviewViewModel vm) {
    _swiperController.swipe(CardSwiperDirection.right);
  }

  Widget _message({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback action,
    Key? retryKey,
  }) =>
      AppCard(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42.sp, color: AppColors.primary),
            SizedBox(height: AppSpacing.sm.h),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: AppSpacing.xs.h),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.md.h),
            FilledButton.icon(
              key: retryKey,
              onPressed: action,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                context.read<AppLanguageProvider>().translate('common.retry'),
              ),
            )
          ],
        ),
      );
}
