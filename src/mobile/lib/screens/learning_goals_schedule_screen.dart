import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class LearningGoalsScheduleScreen extends StatefulWidget {
  const LearningGoalsScheduleScreen({super.key});

  @override
  State<LearningGoalsScheduleScreen> createState() =>
      _LearningGoalsScheduleScreenState();
}

class _LearningGoalsScheduleScreenState
    extends State<LearningGoalsScheduleScreen> {
  bool _reminder = true;
  bool _isSaving = false;

  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = context.read<AuthRepository>();
      final profile = await repo.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _reminder = profile.studyReminderEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _persist(Map<String, Object?> values) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    try {
      final profile = await context.read<AuthRepository>().updateProfile(
        values,
      );
      if (!mounted) return true;
      setState(() {
        _profile = profile;
        _reminder = profile.studyReminderEnabled;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AppLanguageProvider>().translate(
                'profile.save_failed',
              ),
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggle(
    String field,
    bool value,
    bool oldValue,
    void Function(bool) apply,
  ) async {
    setState(() => apply(value));
    if (!await _persist({field: value}) && mounted) {
      setState(() => apply(oldValue));
    }
  }

  Future<void> _chooseDailyGoal() async {
    final l10n = context.read<AppLanguageProvider>();
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: Text(
                  l10n.translate('profile.settings.daily_goal'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              ...[15, 30, 45, 60, 90].map(
                (minutes) => ListTile(
                  title: Text(
                    '$minutes ${l10n.currentLanguage == AppLanguage.vi ? 'phút / ngày' : 'minutes / day'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  trailing: _profile?.dailyGoalMinutes == minutes
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, minutes),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
    if (value != null) await _persist({'dailyGoalMinutes': value});
  }

  Future<void> _chooseTarget() async {
    final l10n = context.read<AppLanguageProvider>();
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: Text(
                  l10n.translate('profile.settings.target_level'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              ...['A1', 'A2', 'B1', 'B2'].map(
                (level) => ListTile(
                  title: Text(
                    level,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  trailing: _profile?.targetCefr == level
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, level),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
    if (value != null) await _persist({'targetCefr': value});
  }

  Future<void> _editPurpose() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
          _PurposeBottomSheet(initialPurpose: _profile?.learningPurpose),
    );
    if (value != null) await _persist({'learningPurpose': value});
  }

  Future<void> _chooseFocusSkills() async {
    final l10n = context.read<AppLanguageProvider>();
    List<SkillCatalogItem> skills;
    try {
      skills = await context.read<ProgressRepository>().skills();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('profile.save_failed'))),
        );
      }
      return;
    }
    if (!mounted) return;
    final selected = <int>{...?_profile?.focusSkillIds};
    final value = await showModalBottomSheet<List<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('profile.settings.focus_skills'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 360.h),
                  child: ListView(
                    shrinkWrap: true,
                    children: skills
                        .where((skill) => skill.parentId != null)
                        .map<Widget>(
                          (skill) => CheckboxListTile(
                            value: selected.contains(skill.id),
                            title: Text(
                              l10n.currentLanguage == AppLanguage.vi
                                  ? skill.nameVi
                                  : skill.name,
                            ),
                            onChanged: (checked) => setBottomSheetState(() {
                              if (checked == true) {
                                selected.add(skill.id);
                              } else {
                                selected.remove(skill.id);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.translate('profile.logout_dialog.cancel'),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs.w),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, selected.toList()),
                      child: Text(l10n.translate('profile.save')),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md.h),
              ],
            ),
          ),
        ),
      ),
    );
    if (value != null) await _persist({'focusSkillIds': value});
  }

  Future<void> _chooseReminderTime() async {
    final parts = _profile?.reminderTime?.split(':');
    final initial = parts?.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts![0]) ?? 19,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 19, minute: 0);
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null) {
      final formatted =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      await _persist({'reminderTime': formatted});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile.groups.goals_and_schedule')),
      ),
      body: _isLoading
          ? Semantics(liveRegion: true, child: loadingView())
          : _error != null || profile == null
          ? Center(
              child: Semantics(
                key: const Key('goals_load_error'),
                liveRegion: true,
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Text(l10n.translate('profile.error_load_failed')),
                      SizedBox(height: AppSpacing.md.h),
                      FilledButton(
                        onPressed: _loadProfile,
                        child: Text(l10n.translate('common.retry')),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.margin.w,
                AppSpacing.md.h,
                AppSpacing.margin.w,
                AppSpacing.xl.h,
              ),
              children: [
                _group(
                  l10n,
                  Icons.flag_outlined,
                  l10n.translate('profile.groups.goals'),
                  [
                    _SettingTile(
                      title: l10n.translate('profile.settings.daily_goal'),
                      subtitle:
                          '${profile.dailyGoalMinutes} ${l10n.currentLanguage == AppLanguage.vi ? 'phút / ngày' : 'minutes / day'}',
                      onTap: _isSaving ? null : _chooseDailyGoal,
                    ),
                    _SettingTile(
                      title: l10n.translate('profile.settings.target_level'),
                      subtitle: profile.targetCefrConfirmed
                          ? profile.targetCefr
                          : l10n.translate('profile.not_set'),
                      onTap: _isSaving ? null : _chooseTarget,
                    ),
                    _SettingTile(
                      title: l10n.translate(
                        'profile.settings.learning_purpose',
                      ),
                      subtitle: profile.learningPurpose?.isNotEmpty == true
                          ? profile.learningPurpose
                          : l10n.translate('profile.not_set'),
                      onTap: _isSaving ? null : _editPurpose,
                    ),
                    _SettingTile(
                      title: l10n.translate('profile.settings.focus_skills'),
                      subtitle: l10n.translate('profile.skills_selected', [
                        profile.focusSkillIds.length,
                      ]),
                      onTap: _isSaving ? null : _chooseFocusSkills,
                    ),
                  ],
                ),
                _group(
                  l10n,
                  Icons.calendar_month_outlined,
                  l10n.translate('profile.groups.schedule'),
                  [
                    _SettingTile(
                      title: l10n.translate('profile.settings.study_reminder'),
                      value: _reminder,
                      onChanged: _isSaving
                          ? null
                          : (value) => _toggle(
                              'studyReminderEnabled',
                              value,
                              _reminder,
                              (next) => _reminder = next,
                            ),
                    ),
                    _SettingTile(
                      title: l10n.translate('profile.settings.reminder_time'),
                      subtitle: profile.reminderTime ?? '--:--',
                      onTap: _isSaving ? null : _chooseReminderTime,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _group(
    AppLanguageProvider l10n,
    IconData icon,
    String title,
    List<Widget> children,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        container: true,
        header: true,
        label: title,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20.sp,
                    ),
                    SizedBox(width: AppSpacing.xs.w),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    this.subtitle,
    this.value,
    this.onChanged,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value != null && onChanged != null) {
      return Material(
        color: Colors.transparent,
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          value: value!,
          onChanged: onChanged,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PurposeBottomSheet extends StatefulWidget {
  const _PurposeBottomSheet({required this.initialPurpose});

  final String? initialPurpose;

  @override
  State<_PurposeBottomSheet> createState() => _PurposeBottomSheetState();
}

class _PurposeBottomSheetState extends State<_PurposeBottomSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPurpose);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.read<AppLanguageProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 100),
      curve: Curves.decelerate,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md.w,
            AppSpacing.sm.h,
            AppSpacing.md.w,
            AppSpacing.md.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('profile.settings.learning_purpose'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              TextField(
                controller: _controller,
                maxLength: 100,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.translate('profile.settings.learning_purpose'),
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.translate('profile.logout_dialog.cancel')),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _controller.text.trim()),
                    child: Text(l10n.translate('profile.save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
