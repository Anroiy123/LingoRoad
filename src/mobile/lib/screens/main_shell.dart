import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/screens/home_screen.dart';
import 'package:lingoroad_mobile/screens/learning_path_screen.dart';
import 'package:lingoroad_mobile/screens/profile_screen.dart';
import 'package:lingoroad_mobile/screens/progress_screen.dart';
import 'package:lingoroad_mobile/screens/review_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.sessionController, super.key});

  final SessionController sessionController;

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
      ProfileScreen(sessionController: widget.sessionController),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Học',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: AppColors.primary),
            label: 'Lộ trình',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
            ),
            label: 'Ôn tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
            ),
            label: 'Tiến độ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
