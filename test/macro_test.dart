import 'dart:ffi';

import 'package:bloxawys/models/macro.dart';
import 'package:bloxawys/services/macro_player.dart';
import 'package:bloxawys/services/macro_recorder.dart';
import 'package:bloxawys/services/raw_input.dart';
import 'package:bloxawys/services/roblox_windows.dart';
import 'package:bloxawys/services/win32.dart';
import 'package:flutter_test/flutter_test.dart';

/// Окна, где hwnd равен ID процесса, а все действия пишутся в журнал.
class _FakeWindows extends RobloxWindows {
  final log = <String>[];
  int fg = 0;

  @override
  bool get supported => true;
  @override
  int? windowForPid(int pid) => pid;
  @override
  int foreground() => fg;
  @override
  void restore(int hwnd) {}
  @override
  bool focus(int hwnd) {
    fg = hwnd;
    log.add('focus $hwnd');
    return true;
  }

  @override
  void sendKey(int scanCode, {bool extended = false, required bool down}) =>
      log.add('$fg key $scanCode ${down ? 'down' : 'up'}');
  @override
  void sendMouseMove(int dx, int dy) => log.add('$fg move $dx $dy');
  @override
  void moveCursorTo(int hwnd, double x, double y) {}
  @override
  void sendMouseButton(MouseButton button, {required bool down}) =>
      log.add('$fg ${button.name} ${down ? 'down' : 'up'}');
  @override
  ({double x, double y})? cursorInWindow(int hwnd) => (x: 0.5, y: 0.25);
}

class _FakeInput extends RawInputListener {
  void Function(RawKey)? onKey;
  void Function(RawMouse)? onMouse;
  void Function()? onStop;

  @override
  void start({
    required void Function(RawKey) onKey,
    required void Function(RawMouse) onMouse,
    required void Function() onStop,
  }) {
    this.onKey = onKey;
    this.onMouse = onMouse;
    this.onStop = onStop;
  }

  @override
  void stop() => onKey = onMouse = onStop = null;
}

MacroEvent _key(int t, int scan, {required bool down}) => MacroEvent(
  t: t,
  type: down ? MacroEventType.keyDown : MacroEventType.keyUp,
  scanCode: scan,
);

Macro _macro(List<MacroEvent> events, int durationMs) =>
    Macro(id: 'm', name: 'm', events: events, durationMs: durationMs);

Future<void> _waitStopped(MacroPlayer player) async {
  for (var i = 0; i < 100 && player.running; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(player.running, isFalse);
}

RawKey _raw(int scan, {bool down = true, bool physical = true}) =>
    RawKey(scanCode: scan, extended: false, down: down, physical: physical);

void main() {
  test('размеры структур WinAPI совпадают с x64 Windows', () {
    expect(sizeOf<WndClassEx>(), 80);
    expect(sizeOf<RawInputDevice>(), 16);
    expect(sizeOf<Point>(), 8);
    expect(sizeOf<Rect>(), 16);
  });

  test('макрос сохраняется и читается', () {
    final macro = _macro([
      _key(0, 30, down: true),
      const MacroEvent(t: 5, type: MacroEventType.move, dx: 3, dy: -4),
      const MacroEvent(
        t: 9,
        type: MacroEventType.buttonDown,
        button: MouseButton.right,
        x: 0.5,
        y: 0.25,
      ),
      const MacroEvent(t: 12, type: MacroEventType.wheel, wheel: -120),
    ], 100);
    final restored = Macro.fromJson(macro.toJson());
    expect(restored.durationMs, 100);
    expect(restored.events, hasLength(4));
    expect(restored.events[0].scanCode, 30);
    expect(restored.events[1].dy, -4);
    expect(restored.events[2].button, MouseButton.right);
    expect(restored.events[2].y, 0.25);
    expect(restored.events[3].wheel, -120);
  });

  test('макрос проигрывается в своём окне', () async {
    final windows = _FakeWindows();
    final player = MacroPlayer(windows, _FakeInput());
    player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        loop: false,
        macro: _macro([_key(0, 30, down: true), _key(20, 30, down: false)], 30),
      ),
    ]);
    await _waitStopped(player);
    expect(windows.log, ['focus 1', '1 key 30 down', '1 key 30 up']);
  });

  test(
    'при переключении окон зажатая клавиша отпускается и нажимается снова',
    () async {
      final windows = _FakeWindows();
      final player = MacroPlayer(windows, _FakeInput());
      player.start([
        // Окно 1 держит W 100 мс, окно 2 в это время нажимает E.
        MacroAssignment(
          userId: 1,
          pid: 1,
          loop: false,
          macro: _macro([
            _key(0, 17, down: true),
            _key(100, 17, down: false),
          ], 100),
        ),
        MacroAssignment(
          userId: 2,
          pid: 2,
          loop: false,
          macro: _macro([
            _key(30, 18, down: true),
            _key(40, 18, down: false),
          ], 40),
        ),
      ]);
      await _waitStopped(player);
      // Переключение на окно 2 занимает время, и его круг сдвигается
      // целиком, поэтому отпускание E оказывается позже отпускания W.
      expect(windows.log, [
        'focus 1',
        '1 key 17 down',
        '1 key 17 up', // W отпущена перед уходом из окна 1
        'focus 2',
        '2 key 18 down',
        '2 key 18 up', // E отпущена перед уходом из окна 2
        'focus 1',
        '1 key 17 down', // W снова нажата после возвращения
        '1 key 17 up', // W отпущена по макросу
        'focus 2',
        '2 key 18 down', // E снова нажата после возвращения
        '2 key 18 up', // E отпущена по макросу
      ]);
    },
  );

  test('повтор идёт по кругу до остановки, клавиши отпускаются', () async {
    final windows = _FakeWindows();
    final player = MacroPlayer(windows, _FakeInput());
    player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        loop: true,
        macro: _macro([_key(0, 30, down: true)], 50),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(player.loopsOf(1), greaterThanOrEqualTo(2));
    player.stop();
    await _waitStopped(player);
    expect(windows.log.last, '1 key 30 up');
  });

  test('макросы останавливаются, если пользователь нажал клавишу', () async {
    final windows = _FakeWindows();
    final input = _FakeInput();
    final player = MacroPlayer(windows, input);
    player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        loop: true,
        macro: _macro([_key(0, 30, down: true)], 50),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Нажатия от SendInput не считаются.
    input.onKey!(_raw(17, physical: false));
    expect(player.running, isTrue);
    input.onKey!(_raw(17));
    await _waitStopped(player);
    expect(player.stopReason, contains('нажали клавишу'));
  });

  test('запись берёт только настоящий ввод в нужном окне', () async {
    final windows = _FakeWindows();
    final input = _FakeInput();
    final recorder = MacroRecorder(windows, input);
    final recording = recorder.record(pid: 7);
    expect(windows.fg, 7);

    input.onKey!(_raw(17)); // W нажата
    input.onKey!(_raw(17)); // автоповтор — пропускается
    input.onKey!(_raw(30, physical: false)); // SendInput — пропускается
    input.onKey!(_raw(RawInputListener.stopKeyScanCode)); // F8 — пропускается
    input.onMouse!(
      const RawMouse(
        dx: 4,
        dy: 1,
        buttonFlags: RawMouse.leftDown,
        wheel: 0,
        physical: true,
      ),
    );
    windows.fg = 99; // пользователь ушёл в другое окно
    input.onKey!(_raw(32)); // D в чужом окне — пропускается
    recorder.stop(); // W так и не отпустили

    final macro = (await recording)!;
    expect(macro.events.map((e) => e.type), [
      MacroEventType.keyDown,
      MacroEventType.move,
      MacroEventType.buttonDown,
      MacroEventType.keyUp,
      MacroEventType.buttonUp,
    ]);
    expect(macro.events.first.t, 0);
    expect(macro.events[0].scanCode, 17);
    expect(macro.events[1].dx, 4);
    expect(macro.events[2].x, 0.5);
    expect(macro.events[3].scanCode, 17);
    expect(input.onKey, isNull);
  });
}
