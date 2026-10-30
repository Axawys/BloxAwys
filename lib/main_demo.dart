import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'main.dart';
import 'models/account.dart';
import 'models/macro.dart';
import 'models/settings.dart';
import 'services/account_store.dart';
import 'services/macro_recorder.dart';
import 'services/macro_store.dart';
import 'services/multi_instance.dart';
import 'services/raw_input.dart';
import 'services/roblox_api.dart';
import 'services/roblox_launcher.dart';
import 'services/roblox_windows.dart';
import 'services/settings_store.dart';

/// Демо-режим для проверки интерфейса без Windows: аккаунты ненастоящие,
/// хранятся в памяти, «запуск» Roblox только изображает работу.
/// Аватары загружаются настоящие, по публичным ID пользователей Roblox.
///
/// Запуск: `flutter run -d linux -t lib/main_demo.dart` или `./run_linux.sh`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    store: _MemoryAccountStore(),
    api: _DemoRobloxApi(),
    launcher: _DemoRobloxLauncher(),
    instances: _DemoMultiInstance(),
    windows: _DemoRobloxWindows(),
    settingsStore: _MemorySettingsStore(),
    macroStore: _MemoryMacroStore(),
    recorder: _DemoMacroRecorder(),
  )..init();
  // Тема и шрифты как на Windows (Segoe UI, если он установлен).
  runApp(BloxAwysApp(controller: controller, platform: TargetPlatform.windows));
}

class _MemoryAccountStore extends AccountStore {
  List<Account> _accounts = [
    Account(
      userId: 156,
      username: 'builderman',
      displayName: 'builderman',
      cookie: 'demo',
    ),
    Account(
      userId: 1,
      username: 'Roblox',
      displayName: 'Roblox',
      cookie: 'demo',
    ),
    Account(
      userId: 261,
      username: 'Shedletsky',
      displayName: 'Shedletsky',
      cookie: 'demo',
      needsRelogin: true,
    ),
  ];

  @override
  Future<List<Account>> load() async => _accounts;

  @override
  Future<void> save(List<Account> accounts) async => _accounts = accounts;
}

class _DemoRobloxApi extends RobloxApi {
  @override
  Future<AuthTicket> getAuthTicket(String cookie) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return AuthTicket('demo', null);
  }
}

class _DemoRobloxLauncher extends RobloxLauncher {
  @override
  String? get exePath => 'RobloxPlayerBeta.exe';

  /// «Процессы» запущенных демо-окон; их видит [_DemoRobloxWindows].
  static final pids = <int>[];

  @override
  Future<int> launch({required String ticket, int? placeId}) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    final pid = 1000 + pids.length;
    pids.add(pid);
    return pid;
  }
}

/// Делает вид, что окна Roblox есть и в них можно нажимать клавиши.
/// Окно «процесса» — сам его ID.
class _DemoRobloxWindows extends RobloxWindows {
  int _foreground = 0;

  @override
  bool get supported => true;

  @override
  List<int> robloxPids() => _DemoRobloxLauncher.pids;

  @override
  bool userActiveWithin(Duration period) => false;

  @override
  Future<void> pressInAll(List<KeyTap> taps) async {}

  @override
  int? windowForPid(int pid) =>
      _DemoRobloxLauncher.pids.contains(pid) ? pid : null;

  @override
  int? ownWindow() => null;

  @override
  int foreground() => _foreground;

  @override
  bool focus(int hwnd) {
    _foreground = hwnd;
    return true;
  }

  @override
  void restore(int hwnd) {}

  @override
  ({double x, double y})? cursorInWindow(int hwnd) => (x: 0.5, y: 0.5);

  @override
  void moveCursorTo(int hwnd, double x, double y) {}

  @override
  void sendKey(int scanCode, {bool extended = false, required bool down}) {}

  @override
  void sendMouseMove(int dx, int dy) {}

  @override
  void sendMouseButton(MouseButton button, {required bool down}) {}

  @override
  void sendWheel(int delta) {}
}

/// Запись в демо ничего не читает: по «Закончить» отдаёт пример макроса.
class _DemoMacroRecorder extends MacroRecorder {
  _DemoMacroRecorder() : super(_DemoRobloxWindows(), RawInputListener());

  Completer<Macro?>? _done;

  @override
  bool get recording => _done != null;

  @override
  Future<Macro?> record({required int pid, bool mouseMovement = true}) {
    final done = _done = Completer<Macro?>();
    return done.future;
  }

  @override
  void stop() {
    final done = _done;
    _done = null;
    done?.complete(
      _sampleMacro(DateTime.now().microsecondsSinceEpoch.toString(), ''),
    );
  }

  @override
  void cancel() {
    final done = _done;
    _done = null;
    done?.complete(null);
  }
}

Macro _sampleMacro(String id, String name) => Macro(
  id: id,
  name: name,
  durationMs: 4200,
  events: [
    for (var i = 0; i < 6; i++) ...[
      MacroEvent(t: i * 700, type: MacroEventType.keyDown, scanCode: 0x12),
      MacroEvent(t: i * 700 + 90, type: MacroEventType.keyUp, scanCode: 0x12),
    ],
  ],
);

class _MemoryMacroStore extends MacroStore {
  List<Macro> _macros = [
    _sampleMacro('demo1', 'Сбор урожая'),
    _sampleMacro('demo2', 'Клики по кнопке'),
  ];

  @override
  Future<List<Macro>> load() async => _macros;

  @override
  Future<void> save(List<Macro> macros) async => _macros = macros;
}

class _MemorySettingsStore extends SettingsStore {
  AppSettings _settings = const AppSettings(
    macros: MacroSettings(enabled: true),
  );

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}

/// Изображает Roblox, запущенный из автозагрузки, пока его не закроют кнопкой.
class _DemoMultiInstance extends MultiInstance {
  var _closed = false;

  @override
  MultiInstanceStatus enable() => _closed
      ? MultiInstanceStatus.enabled
      : MultiInstanceStatus.robloxAlreadyRunning;

  @override
  Future<MultiInstanceStatus> closeRobloxAndEnable() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _closed = true;
    return enable();
  }
}
