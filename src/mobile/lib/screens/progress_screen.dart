import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({this.active = true, super.key});
  final bool active;
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ProgressScreen old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
      _scheduled = false;
      _schedule();
    }
  }

  void _schedule() {
    if (!widget.active || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProgressViewModel>().load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final l = context.watch<AppLanguageProvider>();
    return SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
              padding: EdgeInsets.all(AppSpacing.margin.w),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LingoHeader(streak: null),
                    SizedBox(height: AppSpacing.md.h),
                    Text(l.translate('progress.title'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontSize: 28.sp)),
                    TabBar(controller: _tabs, tabs: [
                      Tab(text: l.translate('progress.tabs.overview')),
                      Tab(text: l.translate('progress.tabs.skills')),
                      Tab(text: l.translate('progress.tabs.achievements'))
                    ])
                  ])),
          Expanded(
              child: TabBarView(controller: _tabs, children: [
            _live(context, l, false),
            _live(context, l, true),
            _unavailable(l)
          ]))
        ]));
  }

  Widget _live(BuildContext context, AppLanguageProvider l, bool skills) {
    final vm = context.watch<ProgressViewModel>();
    if (vm.state == ProgressState.initial ||
        vm.state == ProgressState.loading) {
      return loadingView();
    }
    if (vm.state == ProgressState.error) return _retry(l, vm);
    if (vm.state == ProgressState.empty) {
      return _text(l.translate('progress.empty'));
    }
    final categories = vm.categories;
    return ListView(padding: EdgeInsets.all(AppSpacing.margin.w), children: [
      if (!skills) ...[
        SectionTitle(l.translate('progress.overview.strengths')),
        ...vm.strengths.map((e) => _metric(e, l)),
        SizedBox(height: AppSpacing.md.h),
        SectionTitle(l.translate('progress.overview.improvements')),
        ...vm.improvements.map((e) => _metric(e, l)),
        AppCard(
            child: Text(vm.weakest == null
                ? l.translate('progress.suggestion.start')
                : l.translate('progress.suggestion.weakest', [vm.weakest!]))),
        SizedBox(height: AppSpacing.md.h),
        Text(l.translate('progress.summary_unavailable'))
      ] else ...[
        SectionTitle(l.translate('progress.skills_analysis.title')),
        ...categories.map((e) => _metric(e, l)),
        AppCard(
            child: Text(vm.weakest == null
                ? l.translate('progress.suggestion.start')
                : l.translate('progress.suggestion.weakest', [vm.weakest!])))
      ]
    ]);
  }

  Widget _metric(CategoryProgress e, AppLanguageProvider l) => Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: MetricRow(label: e.category, value: e.percent));
  Widget _retry(AppLanguageProvider l, ProgressViewModel vm) => Center(
      child: FilledButton(
          onPressed: vm.load, child: Text(l.translate('common.retry'))));
  Widget _unavailable(AppLanguageProvider l) =>
      _text(l.translate('progress.achievements_unavailable'));
  Widget _text(String text) => Center(
      child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Text(text, textAlign: TextAlign.center)));
}
