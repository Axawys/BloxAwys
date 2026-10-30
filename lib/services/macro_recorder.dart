import 'dart:async';

import '../models/macro.dart';
import 'raw_input.dart';
import 'roblox_windows.dart';

class MacroException implements Exception {
  MacroException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Записывает клавиатуру и мышь в одном окне Roblox до нажатия F8.
///
/// Записывается только ввод с настоящих устройств и только пока активно
/// выбранное окно.
class MacroRecorder {
  MacroRecorder(this._windows, this._input);

  final RobloxWindows _windows;
  final RawInputListener _input;

  /// Мелкие движения мыши склеиваются в одно действие примерно за кадр.
  static const _moveStepMs = 15;

  Completer<Macro?>? _done;
  int _target = 0;
  bool _mouseMovement = true;
  final _clock = Stopwatch();
  final _events = <MacroEvent>[];
  final _keys = <(int, bool)>{};
  final _buttons = <MouseButton>{};
  int _pendingDx = 0;
  int _pendingDy = 0;
  int _lastMoveMs = 0;

  bool get recording => _done != null;

  /// Делает окно процесса [pid] активным и записывает ввод в нём.
  /// Завершается по F8 или [stop]; null — запись отменена или пуста.
  Future<Macro?> record({required int pid, bool mouseMovement = true}) {
    if (recording) throw MacroException('Запись уже идёт');
    final hwnd = _windows.windowForPid(pid);
    if (hwnd == null) throw MacroException('Окно Roblox не найдено');
    _windows.restore(hwnd);
    if (!_windows.focus(hwnd)) {
      throw MacroException('Не удалось сделать окно Roblox активным');
    }
    _target = hwnd;
    _mouseMovement = mouseMovement;
    _events.clear();
    _keys.clear();
    _buttons.clear();
    _pendingDx = _pendingDy = 0;
    _lastMoveMs = 0;
    _clock
      ..reset()
      ..start();
    final done = _done = Completer<Macro?>();
    _input.start(onKey: _onKey, onMouse: _onMouse, onStop: stop);
    return done.future;
  }

  /// Заканчивает запись и отдаёт макрос.
  void stop() => _finish(keep: true);

  /// Прерывает запись без сохранения.
  void cancel() => _finish(keep: false);

  bool get _inTarget => _windows.foreground() == _target;
  int get _now => _clock.elapsedMilliseconds;

  void _onKey(RawKey key) {
    if (!key.physical) return;
    if (key.scanCode == RawInputListener.stopKeyScanCode && !key.extended) {
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
    if (!mouse.physical) return;
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
    _input.stop();
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
    done.complete(
      Macro(
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
    );
  }
}
