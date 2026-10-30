import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/macro.dart';
import 'raw_input.dart';
import 'roblox_windows.dart';

/// Какой макрос запускать в окне аккаунта.
class MacroAssignment {
  const MacroAssignment({
    required this.userId,
    required this.pid,
    required this.macro,
    required this.loop,
  });

  final int userId;
  final int pid;
  final Macro macro;
  final bool loop;
}

/// Проигрывает макросы в нескольких окнах Roblox.
///
/// Windows отдаёт ввод только активному окну, поэтому действия всех макросов
/// выполняются в одном потоке по времени, а перед действием для другого окна
/// фокус переключается на него. Зажатые клавиши при уходе из окна
/// отпускаются и снова нажимаются при возвращении.
class MacroPlayer extends ChangeNotifier {
  MacroPlayer(this._windows, this._input);

  final RobloxWindows _windows;
  final RawInputListener _input;

  /// Сколько ждать после переключения окна, прежде чем нажимать.
  static const _switchDelay = Duration(milliseconds: 120);

  /// Минимальная длина круга, чтобы пустой макрос не крутился без пауз.
  static const _minLoopMs = 50;

  /// Сколько пикселей нужно сдвинуть настоящую мышь, чтобы остановить макросы.
  static const _userMoveThreshold = 25;

  final _runs = <_Run>[];
  Completer<void>? _stopSignal;
  bool _stopOnUserInput = true;
  int _userMove = 0;
  DateTime _userMoveStart = DateTime.now();

  /// Почему макросы остановились в последний раз; null — доиграли сами
  /// или остановлены кнопкой.
  String? stopReason;

  bool get running => _stopSignal != null;

  bool isPlaying(int userId) => _runs.any((r) => r.userId == userId);

  /// Сколько кругов макрос уже прошёл в окне аккаунта.
  int loopsOf(int userId) {
    for (final r in _runs) {
      if (r.userId == userId) return r.loops;
    }
    return 0;
  }

  /// Запускает макросы и возвращает аккаунты, чьи окна не нашлись.
  List<int> start(
    List<MacroAssignment> assignments, {
    bool stopOnUserInput = true,
  }) {
    if (running) throw StateError('Макросы уже запущены');
    final missing = <int>[];
    final now = DateTime.now();
    for (final a in assignments) {
      final hwnd = _windows.windowForPid(a.pid);
      if (hwnd == null || a.macro.events.isEmpty) {
        missing.add(a.userId);
        continue;
      }
      _windows.restore(hwnd);
      _runs.add(_Run(a, hwnd, now));
    }
    if (_runs.isEmpty) return missing;

    stopReason = null;
    _stopOnUserInput = stopOnUserInput;
    _userMove = 0;
    _stopSignal = Completer<void>();
    _input.start(
      onKey: _onUserKey,
      onMouse: _onUserMouse,
      onStop: () => stop(),
    );
    notifyListeners();
    unawaited(_loop(_windows.foreground()));
    return missing;
  }

  void stop([String? reason]) {
    final signal = _stopSignal;
    if (signal == null || signal.isCompleted) return;
    stopReason = reason;
    signal.complete();
  }

  Future<void> _loop(int previousWindow) async {
    final signal = _stopSignal!;
    try {
      while (!signal.isCompleted && _runs.isNotEmpty) {
        var run = _runs.first;
        for (final r in _runs) {
          if (r.dueAt.isBefore(run.dueAt)) run = r;
        }
        final wait = run.dueAt.difference(DateTime.now());
        if (wait > Duration.zero) await _sleep(wait, signal);
        if (signal.isCompleted) break;

        if (_windows.foreground() != run.hwnd && !await _switchTo(run)) {
          _finishRun(run);
          continue;
        }
        if (signal.isCompleted) break;
        // Если действие запоздало (переключение окна, занятый поток),
        // сдвигается весь круг, чтобы паузы внутри макроса сохранились.
        final late = DateTime.now().difference(run.dueAt);
        if (late > Duration.zero) run.loopStart = run.loopStart.add(late);

        _perform(run, run.current);
        final loops = run.loops;
        if (!run.advance()) {
          _finishRun(run);
          notifyListeners();
        } else if (run.loops != loops) {
          notifyListeners();
        }
      }
    } finally {
      final current = _windows.foreground();
      for (final r in _runs) {
        if (r.hwnd == current) _releaseHeld(r);
      }
      _runs.clear();
      _input.stop();
      _stopSignal = null;
      if (previousWindow != 0) _windows.focus(previousWindow);
      notifyListeners();
    }
  }

  Future<void> _sleep(Duration duration, Completer<void> signal) =>
      Future.any([Future<void>.delayed(duration), signal.future]);

  Future<bool> _switchTo(_Run run) async {
    final current = _windows.foreground();
    for (final r in _runs) {
      if (r.hwnd == current) _releaseHeld(r);
    }
    _windows.restore(run.hwnd);
    if (!_windows.focus(run.hwnd)) return false;
    await _sleep(_switchDelay, _stopSignal!);
    for (final (scanCode, extended) in run.keys) {
      _windows.sendKey(scanCode, extended: extended, down: true);
    }
    for (final button in run.buttons) {
      _windows.sendMouseButton(button, down: true);
    }
    return true;
  }

  /// Отпускает зажатое в окне, но помнит, чтобы нажать снова.
  void _releaseHeld(_Run run) {
    for (final (scanCode, extended) in run.keys) {
      _windows.sendKey(scanCode, extended: extended, down: false);
    }
    for (final button in run.buttons) {
      _windows.sendMouseButton(button, down: false);
    }
  }

  void _finishRun(_Run run) {
    if (_windows.foreground() == run.hwnd) _releaseHeld(run);
    _runs.remove(run);
  }

  void _perform(_Run run, MacroEvent e) {
    switch (e.type) {
      case MacroEventType.keyDown:
        _windows.sendKey(e.scanCode, extended: e.extended, down: true);
        run.keys.add((e.scanCode, e.extended));
      case MacroEventType.keyUp:
        _windows.sendKey(e.scanCode, extended: e.extended, down: false);
        run.keys.remove((e.scanCode, e.extended));
      case MacroEventType.move:
        _windows.sendMouseMove(e.dx, e.dy);
      case MacroEventType.buttonDown:
      case MacroEventType.buttonUp:
        final down = e.type == MacroEventType.buttonDown;
        if (e.x != null && e.y != null) {
          _windows.moveCursorTo(run.hwnd, e.x!, e.y!);
        }
        _windows.sendMouseButton(e.button, down: down);
        down ? run.buttons.add(e.button) : run.buttons.remove(e.button);
      case MacroEventType.wheel:
        _windows.sendWheel(e.wheel);
    }
  }

  void _onUserKey(RawKey key) {
    if (!_stopOnUserInput || !key.physical || !key.down) return;
    // F8 обрабатывается горячей клавишей.
    if (key.scanCode == RawInputListener.stopKeyScanCode) return;
    stop('Вы нажали клавишу, макросы остановлены');
  }

  void _onUserMouse(RawMouse mouse) {
    if (!_stopOnUserInput || !mouse.physical) return;
    if (mouse.buttonFlags != 0) {
      stop('Вы нажали кнопку мыши, макросы остановлены');
      return;
    }
    // Небольшое дрожание мыши на столе не считается.
    final now = DateTime.now();
    if (now.difference(_userMoveStart) > const Duration(seconds: 1)) {
      _userMove = 0;
      _userMoveStart = now;
    }
    _userMove += mouse.dx.abs() + mouse.dy.abs();
    if (_userMove > _userMoveThreshold) {
      stop('Вы сдвинули мышь, макросы остановлены');
    }
  }
}

class _Run {
  _Run(this.assignment, this.hwnd, this.loopStart);

  final MacroAssignment assignment;
  final int hwnd;
  DateTime loopStart;
  int index = 0;
  int loops = 0;
  final keys = <(int, bool)>{};
  final buttons = <MouseButton>{};

  int get userId => assignment.userId;
  Macro get macro => assignment.macro;
  MacroEvent get current => macro.events[index];
  DateTime get dueAt => loopStart.add(Duration(milliseconds: current.t));

  /// Переходит к следующему действию; false — макрос закончился.
  bool advance() {
    index++;
    if (index < macro.events.length) return true;
    if (!assignment.loop) return false;
    index = 0;
    loops++;
    final length = macro.durationMs < MacroPlayer._minLoopMs
        ? MacroPlayer._minLoopMs
        : macro.durationMs;
    loopStart = loopStart.add(Duration(milliseconds: length));
    return true;
  }
}
