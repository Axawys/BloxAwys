import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models/settings.dart';
import 'services/title_bar.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController()..init();
  runApp(BloxAwysApp(controller: controller));
}

class BloxAwysApp extends StatefulWidget {
  const BloxAwysApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<BloxAwysApp> createState() => _BloxAwysAppState();
}

class _BloxAwysAppState extends State<BloxAwysApp> with WidgetsBindingObserver {
  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  /// Какой сейчас шапка окна; null — неизвестно, нужно выставить.
  bool? _titleBarDark;
  int _titleBarAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Windows перекрашивает шапку по теме системы, её нужно вернуть.
    setState(() => _titleBarDark = null);
  }

  void _syncTitleBar(bool dark) {
    if (_titleBarDark == dark) return;
    _titleBarDark = dark;
    _titleBarAttempts = 0;
    _applyTitleBar(dark);
  }

  /// Окно показывается после первого кадра, поэтому шапку не всегда
  /// удаётся перекрасить сразу.
  void _applyTitleBar(bool dark) {
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _titleBarDark != dark) return;
      if (!TitleBar.setDark(dark) && ++_titleBarAttempts < 10) {
        _applyTitleBar(dark);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final mode = switch (widget.controller.settings.theme) {
          AppTheme.system => ThemeMode.system,
          AppTheme.light => ThemeMode.light,
          AppTheme.dark => ThemeMode.dark,
        };
        final platform = WidgetsBinding.instance.platformDispatcher;
        _syncTitleBar(
          mode == ThemeMode.dark ||
              mode == ThemeMode.system &&
                  platform.platformBrightness == Brightness.dark,
        );
        return MaterialApp(
          title: 'BloxAwys',
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: mode,
          home: HomePage(controller: widget.controller),
        );
      },
    );
  }
}
