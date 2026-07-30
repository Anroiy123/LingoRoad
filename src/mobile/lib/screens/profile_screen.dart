import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
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


  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return AppPage(
      children: [
        const LingoHeader(),
        AppCard(
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFixed,
                  border: Border.all(color: AppColors.cta, width: 2),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Trần Quang Hùng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDisabled,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.translate('profile.status', [12, 'B1', 6]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceHigh),
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
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceHigh, width: .5),
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
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
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
              ),
          ],
        ),
      ),
    );
  }
}
