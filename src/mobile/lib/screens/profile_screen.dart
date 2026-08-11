import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
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

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.read<AppLanguageProvider>().translate(
            'profile.settings.change_password',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.read<AppLanguageProvider>().translate(
                  'profile.current_password',
                ),
              ),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.read<AppLanguageProvider>().translate(
                  'profile.new_password',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.read<AppLanguageProvider>().translate(
                'profile.logout_dialog.cancel',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.read<AppLanguageProvider>().translate('profile.save'),
            ),
          ),
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
        currentPassword: current.text,
        newPassword: next.text,
      );
      if (mounted) await session.logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AppLanguageProvider>().translate(
                'profile.password_failed',
              ),
            ),
          ),
        );
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
                horizontal: AppSpacing.xl.w,
                vertical: AppSpacing.xl.h,
              ),
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
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 48.sp,
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  l10n.translate('profile.error_load_failed'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 16.sp),
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
              _ProfileAvatar(profile: profile),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                profile.name.isEmpty
                    ? profile.email.split('@')[0]
                    : profile.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 20.sp),
              ),
              SizedBox(height: AppSpacing.xs.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99.r),
                ),
                child: Text(
                  l10n.translate('profile.status', [
                    profile.level,
                    profile.cefrLevel,
                    profile.badgesCount,
                  ]),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          header: true,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: _SettingTile(
              title: l10n.translate('profile.groups.goals_and_schedule'),
              subtitle:
                  '${profile.dailyGoalMinutes} ${l10n.currentLanguage == AppLanguage.vi ? 'phút / ngày' : 'minutes / day'} • ${profile.targetCefrConfirmed ? profile.targetCefr : l10n.translate('profile.not_set')}',
              onTap: () async {
                await context.push('/learning-goals-schedule');
                _loadProfile();
              },
            ),
          ),
        ),
        Semantics(
          header: true,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: _SettingTile(
              title: l10n.translate('profile.groups.notifications'),
              subtitle: l10n.translate(
                'profile.settings.notifications_subtitle',
              ),
              onTap: () async {
                await context.push('/notification-settings');
                _loadProfile();
              },
            ),
          ),
        ),
        _group(
          l10n,
          Icons.manage_accounts_outlined,
          l10n.translate('profile.groups.account'),
          [
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
                      child: Text(
                        l10n.translate('profile.logout_dialog.cancel'),
                      ),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final session = context.read<SessionController>();
                        try {
                          await context.read<AuthRepository>().logout(
                            session.refreshToken,
                          );
                        } catch (_) {
                          // Server logout is best-effort; always clear local secrets.
                        } finally {
                          await session.logout();
                        }
                      },
                      child: Text(
                        l10n.translate('profile.logout_dialog.confirm'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.onboarding)
          FilledButton.icon(
            key: const Key('profile_setup_complete'),
            onPressed: !profile.targetCefrConfirmed
                ? null
                : () => context.go('/home'),
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.translate('profile.complete_setup')),
          ),
      ],
    );
  }

  Widget _group(
    AppLanguageProvider l10n,
    IconData icon,
    String title,
    List<Widget> children,
  ) {
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
                Icon(
                  icon,
                  size: 20.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: AppSpacing.sm.w),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 14.sp),
                ),
              ],
            ),
          ),
          Divider(
            height: 1.h,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
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
    this.onTap,
    this.danger = false,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 64.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: .5.w,
              ),
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
                        color: danger
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontSize: 14.sp,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: danger
                              ? theme.colorScheme.error.withValues(alpha: 0.7)
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                danger ? Icons.logout_rounded : Icons.chevron_right_rounded,
                color: danger
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                size: 24.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = _profileInitials(profile.name, profile.email);
    final hue = _stableHue(profile.name.isEmpty ? profile.email : profile.name);
    final color = HSLColor.fromAHSL(1, hue, .46, .88).toColor();
    return Semantics(
      label: context.read<AppLanguageProvider>().translate(
        'home.avatar_semantics',
        [profile.name.isEmpty ? profile.email.split('@').first : profile.name],
      ),
      image: true,
      child: Container(
        key: const Key('profile_initials'),
        width: 92.w,
        height: 92.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2.w,
          ),
        ),
        child: Text(
          initials,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _profileInitials(String name, String email) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isNotEmpty) {
    return words.length == 1
        ? words.first.characters.first.toUpperCase()
        : '${words.first.characters.first}${words.last.characters.first}'
              .toUpperCase();
  }
  final fallback = email.split('@').first.trim();
  return fallback.isEmpty ? '?' : fallback.characters.first.toUpperCase();
}

double _stableHue(String source) =>
    source.runes.fold<int>(0, (hash, rune) => (hash * 31 + rune) & 0x7fffffff) %
    360;
