import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/screens/home_screen.dart';
import 'package:lingoroad_mobile/screens/learning_path_screen.dart';
import 'package:lingoroad_mobile/screens/profile_screen.dart';
import 'package:lingoroad_mobile/screens/progress_screen.dart';
import 'package:lingoroad_mobile/screens/review_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';


class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const LearningPathScreen(),
      const ReviewScreen(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];
  }


  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppLanguageProvider>();
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded, color: AppColors.primary),
            label: l10n.translate('nav.learn'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded, color: AppColors.primary),
            label: l10n.translate('nav.path'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
            ),
            label: l10n.translate('nav.review'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
            ),
            label: l10n.translate('nav.progress'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
            label: l10n.translate('nav.profile'),
          ),
        ],
      ),
    );
  }
}
