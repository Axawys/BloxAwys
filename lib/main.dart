import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController()..init();
  runApp(BloxAwysApp(controller: controller));
}

class BloxAwysApp extends StatelessWidget {
  const BloxAwysApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B82F6),
        brightness: brightness,
      ),
    );

    return MaterialApp(
      title: 'BloxAwys',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: HomePage(controller: controller),
    );
  }
}
