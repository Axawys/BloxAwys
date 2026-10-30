import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../models/macro.dart';
import 'win32.dart' as win;

/// Нажатие одной клавиши по скан-коду. Игры читают скан-коды надёжнее,
/// чем виртуальные коды клавиш.
class KeyTap {
  const KeyTap(
    this.scanCode, {
    this.extended = false,
    this.hold = const Duration(milliseconds: 120),
  });

  final int scanCode;

  /// Стрелки и некоторые другие клавиши — «расширенные».
  final bool extended;

  /// Сколько держать клавишу нажатой.
  final Duration hold;

  static const left = KeyTap(
    0x4B,
    extended: true,
    hold: Duration(milliseconds: 150),
  );
  static const right = KeyTap(
    0x4D,
    extended: true,
    hold: Duration(milliseconds: 150),
  );
  static const a = KeyTap(0x1E);
  static const d = KeyTap(0x20);
  static const space = KeyTap(0x39, hold: Duration(milliseconds: 60));
}

/// Окна Roblox: поиск, переключение фокуса и нажатие клавиш.
///
/// Windows отдаёт ввод только активному окну, поэтому клавиши нажимаются
/// по очереди: окно делается активным, получает нажатия, а в конце фокус
/// возвращается туда, где он был.
class RobloxWindows {
  static const _gwOwner = 4;
  static const _swRestore = 9;
  static const _swShowMinNoActive = 7;
  static const _inputMouse = 0;
  static const _inputKeyboard = 1;
  static const _mouseeventfMove = 0x0001;
  static const _mouseeventfWheel = 0x0800;
  static const _keyeventfExtendedKey = 0x0001;
  static const _keyeventfKeyUp = 0x0002;
  static const _keyeventfScancode = 0x0008;

  bool get supported => Platform.isWindows;

  /// ID запущенных процессов Roblox.
  List<int> robloxPids() => supported ? win.robloxPlayerPids() : const [];

  /// Пользователь трогал мышь или клавиатуру за последние [period].
  bool userActiveWithin(Duration period) {
    if (!supported) return false;
    final info = calloc<win.LastInputInfo>();
    try {
      info.ref.cbSize = sizeOf<win.LastInputInfo>();
      if (win.getLastInputInfo(info) == 0) return false;
      // GetTickCount переполняется раз в 49 дней, поэтому разница по модулю.
      final idleMs = (win.getTickCount() - info.ref.dwTime) & 0xFFFFFFFF;
      return idleMs < period.inMilliseconds;
    } finally {
      calloc.free(info);
    }
  }

  /// Нажимает [taps] по очереди в каждом окне Roblox.
  Future<void> pressInAll(List<KeyTap> taps) async {
    if (!supported) return;
    final windows = _findWindows();
    if (windows.isEmpty) return;

    final previous = win.getForegroundWindow();
    for (final hwnd in windows) {
      final minimized = win.isIconic(hwnd) != 0;
      if (minimized) win.showWindow(hwnd, _swRestore);
      if (win.getForegroundWindow() != hwnd) {
        if (!focus(hwnd)) {
          if (minimized) win.showWindow(hwnd, _swShowMinNoActive);
          continue;
        }
        // Окну нужно время, чтобы обработать активацию.
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      for (final tap in taps) {
        sendKey(tap.scanCode, extended: tap.extended, down: true);
        await Future<void>.delayed(tap.hold);
        sendKey(tap.scanCode, extended: tap.extended, down: false);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (minimized) win.showWindow(hwnd, _swShowMinNoActive);
    }
    if (previous != 0 && win.getForegroundWindow() != previous) {
      focus(previous);
    }
  }

  /// Главное окно процесса Roblox с этим ID.
  int? windowForPid(int pid) {
    if (!supported) return null;
    final found = _findWindows({pid});
    return found.isEmpty ? null : found.first;
  }

  /// Главное окно самого клиента, чтобы вернуть ему фокус.
  int? ownWindow() {
    if (!supported) return null;
    final found = _findWindows({win.getCurrentProcessId()});
    return found.isEmpty ? null : found.first;
  }

  int foreground() => supported ? win.getForegroundWindow() : 0;

  /// Разворачивает окно, если оно свёрнуто.
  void restore(int hwnd) {
    if (supported && win.isIconic(hwnd) != 0) win.showWindow(hwnd, _swRestore);
  }

  /// Положение курсора внутри окна в долях его размера; null, если курсор
  /// за пределами окна.
  ({double x, double y})? cursorInWindow(int hwnd) {
    if (!supported) return null;
    final point = calloc<win.Point>();
    final rect = calloc<win.Rect>();
    try {
      win.getCursorPos(point);
      win.screenToClient(hwnd, point);
      win.getClientRect(hwnd, rect);
      final w = rect.ref.right, h = rect.ref.bottom;
      if (w <= 0 || h <= 0) return null;
      final x = point.ref.x / w, y = point.ref.y / h;
      if (x < 0 || x > 1 || y < 0 || y > 1) return null;
      return (x: x, y: y);
    } finally {
      calloc.free(point);
      calloc.free(rect);
    }
  }

  /// Ставит курсор в точку окна, заданную в долях его размера.
  void moveCursorTo(int hwnd, double x, double y) {
    if (!supported) return;
    final point = calloc<win.Point>();
    final rect = calloc<win.Rect>();
    try {
      win.getClientRect(hwnd, rect);
      point.ref
        ..x = (rect.ref.right * x).round()
        ..y = (rect.ref.bottom * y).round();
      win.clientToScreen(hwnd, point);
      win.setCursorPos(point.ref.x, point.ref.y);
    } finally {
      calloc.free(point);
      calloc.free(rect);
    }
  }

  void sendKey(int scanCode, {bool extended = false, required bool down}) {
    if (!supported) return;
    final input = calloc<win.Input>();
    try {
      input.ref.type = _inputKeyboard;
      final ki = input.ref.u.ki;
      ki.wVk = 0;
      ki.wScan = scanCode;
      ki.dwFlags =
          _keyeventfScancode |
          (extended ? _keyeventfExtendedKey : 0) |
          (down ? 0 : _keyeventfKeyUp);
      win.sendInput(1, input, sizeOf<win.Input>());
    } finally {
      calloc.free(input);
    }
  }

  void sendMouseMove(int dx, int dy) =>
      _sendMouse(_mouseeventfMove, dx: dx, dy: dy);

  void sendMouseButton(MouseButton button, {required bool down}) {
    // MOUSEEVENTF_*DOWN; флаг отпускания всегда вдвое больше.
    final downFlag = switch (button) {
      MouseButton.left => 0x0002,
      MouseButton.right => 0x0008,
      MouseButton.middle => 0x0020,
    };
    _sendMouse(down ? downFlag : downFlag * 2);
  }

  void sendWheel(int delta) => _sendMouse(_mouseeventfWheel, data: delta);

  void _sendMouse(int flags, {int dx = 0, int dy = 0, int data = 0}) {
    if (!supported) return;
    final input = calloc<win.Input>();
    try {
      input.ref.type = _inputMouse;
      final mi = input.ref.u.mi;
      mi.dx = dx;
      mi.dy = dy;
      mi.mouseData = data;
      mi.dwFlags = flags;
      win.sendInput(1, input, sizeOf<win.Input>());
    } finally {
      calloc.free(input);
    }
  }

  static final _found = <int>[];
  static Set<int> _pids = {};

  static int _collect(int hwnd, int lParam) {
    if (win.isWindowVisible(hwnd) == 0) return 1;
    if (win.getWindow(hwnd, _gwOwner) != 0) return 1;
    final pid = calloc<Uint32>();
    try {
      win.getWindowThreadProcessId(hwnd, pid);
      if (_pids.contains(pid.value)) _found.add(hwnd);
    } finally {
      calloc.free(pid);
    }
    return 1;
  }

  /// Видимые главные окна процессов [pids] (по умолчанию — всех процессов
  /// Roblox), включая свёрнутые.
  List<int> _findWindows([Set<int>? pids]) {
    _pids = pids ?? win.robloxPlayerPids().toSet();
    if (_pids.isEmpty) return const [];
    _found.clear();
    win.enumWindows(Pointer.fromFunction<win.EnumWindowsProc>(_collect, 0), 0);
    return [..._found];
  }

  /// Делает окно активным. Фоновому процессу Windows это обычно не даёт,
  /// поэтому поток клиента на время подключается к вводу активного окна.
  bool focus(int hwnd) {
    if (!supported) return false;
    final foreground = win.getForegroundWindow();
    final foregroundThread = foreground == 0
        ? 0
        : win.getWindowThreadProcessId(foreground, nullptr);
    final ownThread = win.getCurrentThreadId();
    final attach = foregroundThread != 0 && foregroundThread != ownThread;
    if (attach) win.attachThreadInput(ownThread, foregroundThread, 1);
    try {
      win.bringWindowToTop(hwnd);
      win.setForegroundWindow(hwnd);
    } finally {
      if (attach) win.attachThreadInput(ownThread, foregroundThread, 0);
    }
    return win.getForegroundWindow() == hwnd;
  }
}
