import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({this.onboarding = false, super.key});

  final bool onboarding;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reminder = true;
  bool _email = false;
  bool _updates = true;
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
          _email = profile.emailNotifications;
          _updates = profile.appUpdates;
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
      final profile =
          await context.read<AuthRepository>().updateProfile(values);
      if (!mounted) return true;
      setState(() {
        _profile = profile;
        _reminder = profile.studyReminderEnabled;
        _email = profile.emailNotifications;
        _updates = profile.appUpdates;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context
                  .read<AppLanguageProvider>()
                  .translate('profile.save_failed'))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggle(String field, bool value, bool oldValue,
      void Function(bool) apply) async {
    setState(() => apply(value));
    if (!await _persist({field: value}) && mounted) {
      setState(() => apply(oldValue));
    }
  }

  Future<void> _chooseDailyGoal() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context
            .read<AppLanguageProvider>()
            .translate('profile.settings.daily_goal')),
        children: [15, 30, 45, 60, 90]
            .map((minutes) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, minutes),
                  child: Text(
                      '$minutes ${context.read<AppLanguageProvider>().currentLanguage == AppLanguage.vi ? 'phút / ngày' : 'minutes / day'}'),
                ))
            .toList(),
      ),
    );
    if (value != null) await _persist({'dailyGoalMinutes': value});
  }

  Future<void> _chooseTarget() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context
            .read<AppLanguageProvider>()
            .translate('profile.settings.target_level')),
        children: ['A1', 'A2', 'B1', 'B2']
            .map((level) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, level),
                  child: Text(level),
                ))
            .toList(),
      ),
    );
    if (value != null) await _persist({'targetCefr': value});
  }

  Future<void> _editPurpose() async {
    final controller = TextEditingController(text: _profile?.learningPurpose);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context
            .read<AppLanguageProvider>()
            .translate('profile.settings.learning_purpose')),
        content:
            TextField(controller: controller, maxLength: 100, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context
                  .read<AppLanguageProvider>()
                  .translate('profile.logout_dialog.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(context
                  .read<AppLanguageProvider>()
                  .translate('profile.save'))),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await _persist({'learningPurpose': value});
  }

  Future<void> _chooseFocusSkills() async {
    List<SkillCatalogItem> skills;
    try {
      skills = await context.read<ProgressRepository>().skills();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context
                .read<AppLanguageProvider>()
                .translate('profile.save_failed'))));
      }
      return;
    }
    if (!mounted) return;
    final selected = <int>{...?_profile?.focusSkillIds};
    final value = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: Text(context
                    .read<AppLanguageProvider>()
                    .translate('profile.settings.focus_skills')),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 360.h,
                  child: ListView(
                    children: skills
                        .where((skill) => skill.parentId != null)
                        .map<Widget>((skill) => CheckboxListTile(
                              value: selected.contains(skill.id),
                              title: Text(context
                                          .read<AppLanguageProvider>()
                                          .currentLanguage ==
                                      AppLanguage.vi
                                  ? skill.nameVi
                                  : skill.name),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  selected.add(skill.id);
                                } else {
                                  selected.remove(skill.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context
                          .read<AppLanguageProvider>()
                          .translate('profile.logout_dialog.cancel'))),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, selected.toList()),
                      child: Text(context
                          .read<AppLanguageProvider>()
                          .translate('profile.save'))),
                ],
              )),
    );
    if (value != null) await _persist({'focusSkillIds': value});
  }

  Future<void> _chooseReminderTime() async {
    final parts = _profile?.reminderTime?.split(':');
    final initial = parts?.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts![0]) ?? 19,
            minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 19, minute: 0);
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null) {
      final formatted =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      await _persist({'reminderTime': formatted});
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context
            .read<AppLanguageProvider>()
            .translate('profile.settings.change_password')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: context
                      .read<AppLanguageProvider>()
                      .translate('profile.current_password'))),
          TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: context
                      .read<AppLanguageProvider>()
                      .translate('profile.new_password'))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context
                  .read<AppLanguageProvider>()
                  .translate('profile.logout_dialog.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context
                  .read<AppLanguageProvider>()
                  .translate('profile.save'))),
        ],
      ),
    );
    if (submitted != true || next.text.length < 8) {
      current.dispose();
      next.dispose();
      return;
    }
    if (!mounted) {
      current.dispose();
      next.dispose();
      return;
    }
    final repository = context.read<AuthRepository>();
    final session = context.read<SessionController>();
    try {
      await repository.changePassword(
          currentPassword: current.text, newPassword: next.text);
      if (mounted) await session.logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context
                .read<AppLanguageProvider>()
                .translate('profile.password_failed'))));
      }
    } finally {
      current.dispose();
      next.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();

    if (_isLoading) {
      return AppPage(
        children: [
          const LingoHeader(),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl.w, vertical: AppSpacing.xl.h),
              child: const CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return AppPage(
        children: [
          const LingoHeader(),
          AppCard(
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 48.sp),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  l10n.translate('profile.error_load_failed'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: AppSpacing.md.h),
                FilledButton(
                  onPressed: _loadProfile,
                  child: Text(l10n.translate('common.retry')),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final profile = _profile!;

    return AppPage(
      children: [
        const LingoHeader(),
        AppCard(
          child: Column(
            children: [
              Container(
                width: 92.w,
                height: 92.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFixed,
                  border: Border.all(color: AppColors.cta, width: 2.w),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 48.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                profile.name.isEmpty
                    ? profile.email.split('@')[0]
                    : profile.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20.sp),
              ),
              SizedBox(height: AppSpacing.xs.h),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 5.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDisabled,
                  borderRadius: BorderRadius.circular(99.r),
                ),
                child: Text(
                  l10n.translate('profile.status',
                      [profile.level, profile.cefrLevel, profile.badgesCount]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                ),
              ),
            ],
          ),
        ),
        _group(
            l10n, Icons.flag_outlined, l10n.translate('profile.groups.goals'), [
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
            title: l10n.translate('profile.settings.learning_purpose'),
            subtitle: profile.learningPurpose?.isNotEmpty == true
                ? profile.learningPurpose
                : l10n.translate('profile.not_set'),
            onTap: _isSaving ? null : _editPurpose,
          ),
          _SettingTile(
            title: l10n.translate('profile.settings.focus_skills'),
            subtitle: l10n.translate(
                'profile.skills_selected', [profile.focusSkillIds.length]),
            onTap: _isSaving ? null : _chooseFocusSkills,
          ),
        ]),
        _group(l10n, Icons.calendar_month_outlined,
            l10n.translate('profile.groups.schedule'), [
          _SettingTile(
            title: l10n.translate('profile.settings.study_reminder'),
            value: _reminder,
            onChanged: _isSaving
                ? null
                : (value) => _toggle('studyReminderEnabled', value, _reminder,
                    (next) => _reminder = next),
          ),
          _SettingTile(
            title: l10n.translate('profile.settings.reminder_time'),
            subtitle: profile.reminderTime ?? '--:--',
            onTap: _isSaving ? null : _chooseReminderTime,
          ),
        ]),
        _group(l10n, Icons.notifications_none_rounded,
            l10n.translate('profile.groups.notifications'), [
          _SettingTile(
            title: l10n.translate('profile.settings.email_notif'),
            value: _email,
            onChanged: _isSaving
                ? null
                : (value) => _toggle('emailNotifications', value, _email,
                    (next) => _email = next),
          ),
          _SettingTile(
            title: l10n.translate('profile.settings.app_updates'),
            value: _updates,
            onChanged: _isSaving
                ? null
                : (value) => _toggle(
                    'appUpdates', value, _updates, (next) => _updates = next),
          ),
        ]),
        _group(l10n, Icons.manage_accounts_outlined,
            l10n.translate('profile.groups.account'), [
          _SettingTile(
            title: l10n.translate('profile.settings.change_password'),
            onTap: _changePassword,
          ),
          _SettingTile(
            title: l10n.translate('profile.settings.logout'),
            danger: true,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.translate('profile.logout_dialog.title')),
                content: Text(
                  l10n.translate('profile.logout_dialog.content'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.translate('profile.logout_dialog.cancel')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final session = context.read<SessionController>();
                      try {
                        await context
                            .read<AuthRepository>()
                            .logout(session.refreshToken);
                      } catch (_) {
                        // Server logout is best-effort; always clear local secrets.
                      } finally {
                        await session.logout();
                      }
                    },
                    child:
                        Text(l10n.translate('profile.logout_dialog.confirm')),
                  ),
                ],
              ),
            ),
          ),
        ]),
        if (widget.onboarding)
          FilledButton.icon(
            key: const Key('profile_setup_complete'),
            onPressed: _isSaving || !profile.targetCefrConfirmed
                ? null
                : () => context.go('/home'),
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.translate('profile.complete_setup')),
          ),
      ],
    );
  }

  Widget _group(AppLanguageProvider l10n, IconData icon, String title,
      List<Widget> children) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.sm.h,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20.sp, color: AppColors.primary),
                SizedBox(width: AppSpacing.sm.w),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 14.sp)),
              ],
            ),
          ),
          Divider(height: 1.h, color: AppColors.surfaceHigh),
          ...children,
        ],
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
    this.danger = false,
  });
  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 64.h),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.sm.h,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceHigh, width: .5.w),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: danger ? AppColors.error : AppColors.text,
                          fontSize: 14.sp,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                          ),
                    ),
                ],
              ),
            ),
            if (value != null && onChanged != null)
              Switch(value: value!, onChanged: onChanged)
            else
              Icon(
                danger ? Icons.logout_rounded : Icons.chevron_right_rounded,
                color: danger ? AppColors.error : AppColors.textSecondary,
                size: 24.sp,
              ),
          ],
        ),
      ),
    );
  }
}
