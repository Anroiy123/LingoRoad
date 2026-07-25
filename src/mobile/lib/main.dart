import 'package:flutter/material.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

void main() {
  runApp(const LingoRoadApp());
}

class LingoRoadApp extends StatelessWidget {
  const LingoRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lingoRoad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
