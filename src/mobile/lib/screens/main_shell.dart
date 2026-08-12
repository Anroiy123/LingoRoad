import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/screens/home_screen.dart';
import 'package:lingoroad_mobile/screens/learning_path_screen.dart';
import 'package:lingoroad_mobile/screens/profile_screen.dart';
import 'package:lingoroad_mobile/screens/progress_screen.dart';
import 'package:lingoroad_mobile/screens/review_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    final screens = [
      const HomeScreen(),
      LearningPathScreen(active: _index == 1),
      ReviewScreen(active: _index == 2),
      ProgressScreen(active: _index == 3),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        key: const Key('main_navigation_chrome'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColorsDark.shadow
                  : AppColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl.r),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n.translate('nav.learn'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map_rounded),
                label: l10n.translate('nav.path'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: l10n.translate('nav.review'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart_rounded),
                label: l10n.translate('nav.progress'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: l10n.translate('nav.profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
