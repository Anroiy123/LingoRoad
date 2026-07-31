import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reminder = true;
  bool _email = false;
  bool _updates = true;

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();

    if (_isLoading) {
      return AppPage(
        children: [
          const LingoHeader(),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w, vertical: AppSpacing.xl.h),
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
                Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48.sp),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  l10n.translate('profile.error_load_failed'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16.sp),
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
                profile.name.isEmpty ? profile.email.split('@')[0] : profile.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20.sp),
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
                  l10n.translate('profile.status', [profile.level, profile.cefrLevel, profile.badgesCount]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                ),
              ),
            ],
          ),
        ),
        _group(l10n, Icons.flag_outlined, l10n.translate('profile.groups.goals'), [
          _SettingTile(
            title: l10n.translate('profile.settings.daily_goal'),
            subtitle: l10n.translate('profile.settings.daily_goal_val'),
          ),
          _SettingTile(
            title: l10n.translate('profile.settings.target_level'),
            subtitle: l10n.translate('profile.settings.target_level_val'),
          ),
        ]),
        _group(l10n, Icons.calendar_month_outlined, l10n.translate('profile.groups.schedule'), [
          _SettingTile(
            title: l10n.translate('profile.settings.study_reminder'),
            value: _reminder,
            onChanged: (value) => setState(() => _reminder = value),
          ),
          _SettingTile(title: l10n.translate('profile.settings.reminder_time')),
        ]),
        _group(l10n, Icons.notifications_none_rounded, l10n.translate('profile.groups.notifications'), [
          _SettingTile(
            title: l10n.translate('profile.settings.email_notif'),
            value: _email,
            onChanged: (value) => setState(() => _email = value),
          ),
          _SettingTile(
            title: l10n.translate('profile.settings.app_updates'),
            value: _updates,
            onChanged: (value) => setState(() => _updates = value),
          ),
        ]),
        _group(l10n, Icons.manage_accounts_outlined, l10n.translate('profile.groups.account'), [
          _SettingTile(title: l10n.translate('profile.settings.change_password')),
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
                      await context.read<SessionController>().logout();
                    },
                    child: Text(l10n.translate('profile.logout_dialog.confirm')),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _group(AppLanguageProvider l10n, IconData icon, String title, List<Widget> children) {
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
                Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14.sp)),
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
