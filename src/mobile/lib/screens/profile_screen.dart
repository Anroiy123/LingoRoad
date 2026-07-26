import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.sessionController, super.key});

  final SessionController sessionController;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reminder = true;
  bool _email = false;
  bool _updates = true;

  @override
  Widget build(BuildContext context) {
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
                  'Cấp 12 · B1 · 6 huy hiệu',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        ),
        _group(Icons.flag_outlined, 'Mục tiêu học tập', [
          const _SettingTile(
            title: 'Mục tiêu hằng ngày',
            subtitle: '30 phút / ngày',
          ),
          const _SettingTile(
            title: 'Trình độ mục tiêu',
            subtitle: 'B2 - Trung cao cấp',
          ),
        ]),
        _group(Icons.calendar_month_outlined, 'Lịch học', [
          _SettingTile(
            title: 'Nhắc nhở học tập',
            value: _reminder,
            onChanged: (value) => setState(() => _reminder = value),
          ),
          const _SettingTile(title: 'Cài đặt thời gian nhắc nhở'),
        ]),
        _group(Icons.notifications_none_rounded, 'Thông báo', [
          _SettingTile(
            title: 'Thông báo qua Email',
            value: _email,
            onChanged: (value) => setState(() => _email = value),
          ),
          _SettingTile(
            title: 'Cập nhật ứng dụng',
            value: _updates,
            onChanged: (value) => setState(() => _updates = value),
          ),
        ]),
        _group(Icons.manage_accounts_outlined, 'Tài khoản', [
          const _SettingTile(title: 'Đổi mật khẩu'),
          _SettingTile(
            title: 'Đăng xuất',
            danger: true,
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Đăng xuất'),
                content: const Text(
                  'Đây là thao tác mô phỏng trong phiên bản giao diện.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.sessionController.logout();
                    },
                    child: const Text('Đồng ý'),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _group(IconData icon, String title, List<Widget> children) {
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
