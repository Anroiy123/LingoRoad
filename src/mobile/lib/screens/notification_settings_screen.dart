import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/theme/app_theme_provider.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
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
      final profile = await context.read<AuthRepository>().updateProfile(
        values,
      );
      if (!mounted) return true;
      setState(() {
        _profile = profile;
        _email = profile.emailNotifications;
        _updates = profile.appUpdates;
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

  Future<void> _chooseLanguage() async {
    final l10n = context.read<AppLanguageProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: Text(
                  l10n.translate('profile.settings.language'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  l10n.translate('profile.settings.language_vi'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: l10n.currentLanguage == AppLanguage.vi
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  l10n.setLanguage(AppLanguage.vi);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  l10n.translate('profile.settings.language_en'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: l10n.currentLanguage == AppLanguage.en
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  l10n.setLanguage(AppLanguage.en);
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseTheme() async {
    final l10n = context.read<AppLanguageProvider>();
    final themeProvider = context.read<AppThemeProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: Text(
                  l10n.translate('profile.settings.theme'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  l10n.translate('profile.settings.theme_system'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: themeProvider.themeMode == ThemeMode.system
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  l10n.translate('profile.settings.theme_light'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: themeProvider.themeMode == ThemeMode.light
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  l10n.translate('profile.settings.theme_dark'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: themeProvider.themeMode == ThemeMode.dark
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  themeProvider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final themeProvider = context.watch<AppThemeProvider>();
    final themeText = switch (themeProvider.themeMode) {
      ThemeMode.light => l10n.translate('profile.settings.theme_light'),
      ThemeMode.dark => l10n.translate('profile.settings.theme_dark'),
      _ => l10n.translate('profile.settings.theme_system'),
    };
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile.groups.notifications')),
      ),
      body: _isLoading
          ? Semantics(liveRegion: true, child: loadingView())
          : _error != null || profile == null
          ? Center(
              child: Semantics(
                key: const Key('settings_load_error'),
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
                  Icons.notifications_none_rounded,
                  l10n.translate('profile.groups.notifications'),
                  [
                    _SettingTile(
                      title: l10n.translate('profile.settings.email_notif'),
                      value: _email,
                      onChanged: _isSaving
                          ? null
                          : (value) => _toggle(
                              'emailNotifications',
                              value,
                              _email,
                              (next) => _email = next,
                            ),
                    ),
                    _SettingTile(
                      title: l10n.translate('profile.settings.app_updates'),
                      value: _updates,
                      onChanged: _isSaving
                          ? null
                          : (value) => _toggle(
                              'appUpdates',
                              value,
                              _updates,
                              (next) => _updates = next,
                            ),
                    ),
                  ],
                  headingKey: const Key('settings_notifications_heading'),
                ),
                _group(
                  l10n,
                  Icons.tune_rounded,
                  l10n.translate('profile.settings.preferences'),
                  [
                    _SettingTile(
                      title: l10n.translate('profile.settings.language'),
                      subtitle: l10n.currentLanguage == AppLanguage.vi
                          ? l10n.translate('profile.settings.language_vi')
                          : l10n.translate('profile.settings.language_en'),
                      onTap: _chooseLanguage,
                    ),
                    _SettingTile(
                      title: l10n.translate('profile.settings.theme'),
                      subtitle: themeText,
                      onTap: _chooseTheme,
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
    List<Widget> children, {
    Key? headingKey,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        key: headingKey,
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
