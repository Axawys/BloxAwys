import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/macro.dart';
import 'raw_input.dart';
import 'recording_indicator.dart';
import 'roblox_windows.dart';

class MacroException implements Exception {
  MacroException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Записанный макрос и процесс Roblox, в окне которого он записан.
typedef RecordedMacro = ({Macro macro, int pid});

/// Записывает клавиатуру и мышь в одном окне Roblox.
///
/// Запись начинается не сразу: сначала клиент ждёт F8, чтобы пользователь
/// успел вернуться в игру. Записывается окно, активное в момент нажатия,
/// до следующего F8. Записывается только ввод с настоящих устройств и только
/// пока активно это окно.
class MacroRecorder extends ChangeNotifier {
  MacroRecorder(this._windows, this._input, [this._indicator]);

  final RobloxWindows _windows;
  final RawInputListener _input;
  final RecordingIndicator? _indicator;

  /// Мелкие движения мыши склеиваются в одно действие примерно за кадр.
  static const _moveStepMs = 15;

  Completer<RecordedMacro?>? _done;
  bool _recording = false;
  Set<int> _pids = {};
  int _target = 0;
  int _targetPid = 0;
  bool _mouseMovement = true;
  final _clock = Stopwatch();
  final _events = <MacroEvent>[];
  final _keys = <(int, bool)>{};
  final _buttons = <MouseButton>{};
  int _pendingDx = 0;
  int _pendingDy = 0;
  int _lastMoveMs = 0;

  /// Запись запущена: ждёт F8 или уже идёт.
  bool get active => _done != null;

  /// Ждёт F8, чтобы начать.
  bool get waiting => active && !_recording;

  /// Записывает ввод.
  bool get recording => active && _recording;

  /// Ждёт F8 в окне одного из процессов Roblox [pids] и записывает ввод
  /// в нём до следующего F8 или [stop]; null — запись отменена или пуста.
  Future<RecordedMacro?> record({
    required Set<int> pids,
    bool mouseMovement = true,
  }) {
    if (active) throw MacroException('Запись уже идёт');
    _pids = pids;
    _mouseMovement = mouseMovement;
    final done = _done = Completer<RecordedMacro?>();
    _input.start(onKey: _onKey, onMouse: _onMouse, onHotkey: _onHotkey);
    _indicator?.show(
      'Нажмите F8, чтобы начать запись',
      style: IndicatorStyle.waiting,
      over: (hwnd) => _pids.contains(_windows.pidOf(hwnd)),
    );
    notifyListeners();
    return done.future;
  }

  void _onHotkey() {
    if (_recording) return stop();
    final hwnd = _windows.foreground();
    final pid = _windows.pidOf(hwnd);
    if (!_pids.contains(pid)) {
      // F8 нажата не в окне Roblox, запущенном из клиента.
      _windows.beep();
      return;
    }
    _begin(hwnd, pid);
  }

  void _begin(int hwnd, int pid) {
    _recording = true;
    _target = hwnd;
    _targetPid = pid;
    _events.clear();
    _keys.clear();
    _buttons.clear();
    _pendingDx = _pendingDy = 0;
    _lastMoveMs = 0;
    _clock
      ..reset()
      ..start();
    _indicator?.show(
      '●  Идёт запись · F8 — закончить',
      style: IndicatorStyle.recording,
      over: (hwnd) => hwnd == _target,
    );
    notifyListeners();
  }

  /// Заканчивает запись и отдаёт макрос. Если F8 ещё не нажимали,
  /// отменяет запись.
  void stop() => _finish(keep: true);

  /// Прерывает запись или ожидание F8 без сохранения.
  void cancel() => _finish(keep: false);

  bool get _inTarget => _windows.foreground() == _target;
  int get _now => _clock.elapsedMilliseconds;

  void _onKey(RawKey key) {
    if (!_recording || !key.physical) return;
    if (key.scanCode == RawInputListener.hotkeyScanCode && !key.extended) {
      return;
    }
    final id = (key.scanCode, key.extended);
    if (key.down) {
      // Повторы при удержании клавиши не нужны: удержание видно по паузе
      // между нажатием и отпусканием.
      if (_keys.contains(id) || !_inTarget) return;
      _keys.add(id);
    } else if (!_keys.remove(id)) {
      return;
    }
    _flushMove();
    _events.add(
      MacroEvent(
        t: _now,
        type: key.down ? MacroEventType.keyDown : MacroEventType.keyUp,
        scanCode: key.scanCode,
        extended: key.extended,
      ),
    );
  }

  void _onMouse(RawMouse mouse) {
    if (!_recording || !mouse.physical) return;
    if (_mouseMovement && (mouse.dx != 0 || mouse.dy != 0) && _inTarget) {
      _pendingDx += mouse.dx;
      _pendingDy += mouse.dy;
      if (_now - _lastMoveMs >= _moveStepMs) _flushMove();
    }
    for (final (button, downFlag, upFlag) in const [
      (MouseButton.left, RawMouse.leftDown, RawMouse.leftUp),
      (MouseButton.right, RawMouse.rightDown, RawMouse.rightUp),
      (MouseButton.middle, RawMouse.middleDown, RawMouse.middleUp),
    ]) {
      if (mouse.buttonFlags & downFlag != 0 && _inTarget) {
        _addButton(button, down: true);
      }
      if (mouse.buttonFlags & upFlag != 0 && _buttons.contains(button)) {
        _addButton(button, down: false);
      }
    }
    if (mouse.wheel != 0 && _inTarget) {
      _flushMove();
      _events.add(
        MacroEvent(t: _now, type: MacroEventType.wheel, wheel: mouse.wheel),
      );
    }
  }

  void _addButton(MouseButton button, {required bool down}) {
    _flushMove();
    final pos = _windows.cursorInWindow(_target);
    down ? _buttons.add(button) : _buttons.remove(button);
    _events.add(
      MacroEvent(
        t: _now,
        type: down ? MacroEventType.buttonDown : MacroEventType.buttonUp,
        button: button,
        x: pos?.x,
        y: pos?.y,
      ),
    );
  }

  void _flushMove() {
    if (_pendingDx == 0 && _pendingDy == 0) return;
    _events.add(
      MacroEvent(
        t: _now,
        type: MacroEventType.move,
        dx: _pendingDx,
        dy: _pendingDy,
      ),
    );
    _pendingDx = _pendingDy = 0;
    _lastMoveMs = _now;
  }

  void _finish({required bool keep}) {
    final done = _done;
    if (done == null) return;
    _done = null;
    final recorded = _recording;
    _recording = false;
    _input.stop();
    _indicator?.hide();
    notifyListeners();
    if (!recorded) {
      done.complete(null);
      return;
    }
    _flushMove();
    final stopMs = _now;
    _clock.stop();
    // Клавиши, отпущенные уже после F8 или в другом окне, отпускаются
    // в конце, иначе при повторе они останутся зажатыми.
    for (final (scanCode, extended) in _keys) {
      _events.add(
        MacroEvent(
          t: stopMs,
          type: MacroEventType.keyUp,
          scanCode: scanCode,
          extended: extended,
        ),
      );
    }
    for (final button in _buttons) {
      _events.add(
        MacroEvent(t: stopMs, type: MacroEventType.buttonUp, button: button),
      );
    }
    if (!keep || _events.isEmpty) {
      done.complete(null);
      return;
    }
    // Время отсчитывается от первого действия, а пауза до F8 остаётся
    // в конце круга.
    final start = _events.first.t;
    done.complete((
      pid: _targetPid,
      macro: Macro(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: '',
        durationMs: stopMs - start + 1,
        events: [
          for (final e in _events)
            MacroEvent(
              t: e.t - start,
              type: e.type,
              scanCode: e.scanCode,
              extended: e.extended,
              dx: e.dx,
              dy: e.dy,
              button: e.button,
              x: e.x,
              y: e.y,
              wheel: e.wheel,
            ),
        ],
      ),
    ));
  }
}
