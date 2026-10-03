import 'package:flutter/material.dart';
import 'controllers/schedule_controller.dart';
import 'views/schedule_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ScheduleController();
  await controller.init(); // Auto-load schedule from disk on launch (User story 14)

  runApp(ProjectSchedulerApp(controller: controller));
}

class ProjectSchedulerApp extends StatelessWidget {
  final ScheduleController controller;

  const ProjectSchedulerApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Scheduler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B4DFF), // Indigo purple
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6EFF),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      themeMode: ThemeMode.system,
      home: ScheduleHomePage(controller: controller),
    );
  }
}
