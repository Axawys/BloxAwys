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
  int pidOf(int hwnd) => hwnd;
  @override
  void beep() => log.add('beep');
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
  void Function()? onHotkey;

  @override
  void start({
    required void Function(RawKey) onKey,
    required void Function(RawMouse) onMouse,
    required void Function() onHotkey,
  }) {
    this.onKey = onKey;
    this.onMouse = onMouse;
    this.onHotkey = onHotkey;
  }

  @override
  void stop() => onKey = onMouse = onHotkey = null;
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

/// Пользователь делает окно [window] активным и нажимает F8.
void _pressF8(_FakeWindows windows, _FakeInput input, int window) {
  windows.fg = window;
  input.onHotkey!();
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

  test('макрос проигрывается в своём окне после F8', () async {
    final windows = _FakeWindows();
    final input = _FakeInput();
    final player = MacroPlayer(windows, input);
    player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        mode: MacroPlayMode.once,
        macro: _macro([_key(0, 30, down: true), _key(20, 30, down: false)], 30),
      ),
    ]);
    _pressF8(windows, input, 1);
    await _waitStopped(player);
    expect(windows.log, ['1 key 30 down', '1 key 30 up']);
  });

  test(
    'при переключении окон зажатая клавиша отпускается и нажимается снова',
    () async {
      final windows = _FakeWindows();
      final input = _FakeInput();
      final player = MacroPlayer(windows, input);
      player.start([
        // Окно 1 держит W 100 мс, окно 2 в это время нажимает E.
        MacroAssignment(
          userId: 1,
          pid: 1,
          mode: MacroPlayMode.once,
          macro: _macro([
            _key(0, 17, down: true),
            _key(100, 17, down: false),
          ], 100),
        ),
        MacroAssignment(
          userId: 2,
          pid: 2,
          mode: MacroPlayMode.once,
          macro: _macro([
            _key(30, 18, down: true),
            _key(40, 18, down: false),
          ], 40),
        ),
      ]);
      _pressF8(windows, input, 1);
      await _waitStopped(player);
      // Переключение на окно 2 занимает время, и его круг сдвигается
      // целиком, поэтому отпускание E оказывается позже отпускания W.
      expect(windows.log, [
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
        'focus 1', // фокус вернулся в окно, где нажали F8
      ]);
    },
  );

  test('повтор идёт по кругу до остановки, клавиши отпускаются', () async {
    final windows = _FakeWindows();
    final input = _FakeInput();
    final player = MacroPlayer(windows, input);
    player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        mode: MacroPlayMode.loop,
        macro: _macro([_key(0, 30, down: true)], 50),
      ),
    ]);
    _pressF8(windows, input, 1);
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
        mode: MacroPlayMode.loop,
        macro: _macro([_key(0, 30, down: true)], 50),
      ),
    ]);
    // Пока макросы ждут F8, ввод пользователя их не отменяет.
    input.onKey!(_raw(17));
    expect(player.waiting, isTrue);
    _pressF8(windows, input, 1);
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
    final recording = recorder.record(pids: {7});
    windows.fg = 7;
    input.onHotkey!(); // F8 в окне Roblox — запись пошла
    expect(recorder.recording, isTrue);

    input.onKey!(_raw(17)); // W нажата
    input.onKey!(_raw(17)); // автоповтор — пропускается
    input.onKey!(_raw(30, physical: false)); // SendInput — пропускается
    input.onKey!(_raw(RawInputListener.hotkeyScanCode)); // F8 — пропускается
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
    windows.fg = 7;
    input.onHotkey!(); // F8 — конец записи, W так и не отпустили

    final (:macro, :pid) = (await recording)!;
    expect(pid, 7);
    expect(recorder.active, isFalse);
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

  test('запись не начинается без F8 в окне Roblox', () async {
    final windows = _FakeWindows()..fg = 7;
    final input = _FakeInput();
    final recorder = MacroRecorder(windows, input);
    final recording = recorder.record(pids: {7});
    expect(recorder.waiting, isTrue);
    expect(windows.log, isEmpty); // фокус окон не трогается

    input.onKey!(_raw(17)); // до F8 ничего не пишется
    windows.fg = 99;
    input.onHotkey!(); // F8 не в Roblox — звук, запись не идёт
    expect(windows.log, ['beep']);
    expect(recorder.waiting, isTrue);

    recorder.cancel();
    expect(await recording, isNull);
    expect(recorder.active, isFalse);
    expect(input.onKey, isNull);
  });

  test('зеркальный круг меняет направление и сохраняет тайминг', () {
    final macro = _macro([
      _key(0, 0x1E, down: true), // A
      const MacroEvent(t: 10, type: MacroEventType.move, dx: 5, dy: -2),
      _key(40, 0x1E, down: false),
      _key(50, 0x11, down: true), // W
      _key(60, 0x11, down: false),
      _key(70, 0x39, down: true), // пробел остаётся пробелом
      const MacroEvent(
        t: 80,
        type: MacroEventType.keyDown,
        scanCode: 0x4B, // ←
        extended: true,
      ),
    ], 100);
    final mirrored = macro.mirrored();
    expect(mirrored.durationMs, 100);
    expect(
      [for (final e in mirrored.events) (e.t, e.type, e.scanCode)],
      [
        (0, MacroEventType.keyDown, 0x20), // D
        (10, MacroEventType.move, 0),
        (40, MacroEventType.keyUp, 0x20),
        (50, MacroEventType.keyDown, 0x1F), // S
        (60, MacroEventType.keyUp, 0x1F),
        (70, MacroEventType.keyDown, 0x39),
        (80, MacroEventType.keyDown, 0x4D), // →
      ],
    );
    expect((mirrored.events[1].dx, mirrored.events[1].dy), (-5, 2));
    expect(mirrored.events.last.extended, isTrue);
  });

  test('туда-обратно: нечётные круги как записано, чётные зеркально', () async {
    final windows = _FakeWindows();
    final input = _FakeInput();
    final player = MacroPlayer(windows, input);
    // Влево, пауза, снова влево — как «2 с, 1 с, 2 с», только быстрее.
    player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        mode: MacroPlayMode.pingPong,
        macro: _macro([
          _key(0, 0x1E, down: true),
          _key(20, 0x1E, down: false),
          _key(30, 0x1E, down: true),
          _key(50, 0x1E, down: false),
        ], 50),
      ),
    ]);
    _pressF8(windows, input, 1);
    while (windows.log.length < 12) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    player.stop();
    await _waitStopped(player);
    const left = [
      '1 key 30 down',
      '1 key 30 up',
      '1 key 30 down',
      '1 key 30 up',
    ];
    const right = [
      '1 key 32 down',
      '1 key 32 up',
      '1 key 32 down',
      '1 key 32 up',
    ];
    expect(windows.log.take(12), [...left, ...right, ...left]);
  });

  test('макросы ждут F8 в своём окне и не трогают фокус', () async {
    final windows = _FakeWindows()..fg = 5;
    final input = _FakeInput();
    final player = MacroPlayer(windows, input);
    final missing = player.start([
      MacroAssignment(
        userId: 1,
        pid: 1,
        mode: MacroPlayMode.loop,
        macro: _macro([_key(0, 30, down: true)], 50),
      ),
      MacroAssignment(
        userId: 2,
        pid: 2,
        mode: MacroPlayMode.loop,
        macro: _macro(const [], 50), // пустой макрос не запускается
      ),
    ]);
    expect(missing, [2]);
    expect(player.waiting, isTrue);
    expect(player.running, isFalse);
    expect(player.isPlaying(1), isFalse);

    _pressF8(windows, input, 99); // F8 не в окне макроса — звук
    expect(windows.log, ['beep']);
    expect(player.waiting, isTrue);

    player.stop(); // отмена ожидания
    expect(player.active, isFalse);
    expect(input.onKey, isNull);
    expect(windows.log, ['beep']);
  });
}
