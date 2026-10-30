import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'win32.dart' as win;

/// Нажатие или отпускание клавиши.
class RawKey {
  const RawKey({
    required this.scanCode,
    required this.extended,
    required this.down,
    required this.physical,
  });

  final int scanCode;
  final bool extended;
  final bool down;

  /// От настоящей клавиатуры, а не от SendInput.
  final bool physical;
}

/// Событие мыши: смещение, кнопки и колесо.
class RawMouse {
  const RawMouse({
    required this.dx,
    required this.dy,
    required this.buttonFlags,
    required this.wheel,
    required this.physical,
  });

  final int dx;
  final int dy;

  /// RI_MOUSE_* из winuser.h.
  final int buttonFlags;
  final int wheel;
  final bool physical;

  static const leftDown = 0x0001;
  static const leftUp = 0x0002;
  static const rightDown = 0x0004;
  static const rightUp = 0x0008;
  static const middleDown = 0x0010;
  static const middleUp = 0x0020;
  static const wheelFlag = 0x0400;
}

/// Получает ввод с клавиатуры и мыши через Raw Input, пока запущен,
/// и ловит горячую клавишу остановки F8.
///
/// Ввод приходит в скрытое служебное окно (HWND_MESSAGE) с флагом
/// RIDEV_INPUTSINK, то есть и тогда, когда активно другое окно. Глобальные
/// хуки клавиатуры не используются. Оконная процедура написана на Dart:
/// на Windows Flutter выполняет Dart в потоке окна, поэтому она вызывается
/// синхронно из цикла сообщений.
class RawInputListener {
  static const stopKeyScanCode = 0x42; // F8

  static const _wmInput = 0x00FF;
  static const _wmHotkey = 0x0312;
  static const _hwndMessage = -3;
  static const _ridevInputSink = 0x00000100;
  static const _ridevRemove = 0x00000001;
  static const _ridInput = 0x10000003;
  static const _rimTypeMouse = 0;
  static const _rimTypeKeyboard = 1;
  static const _riKeyBreak = 0x01;
  static const _riKeyE0 = 0x02;
  static const _mouseMoveAbsolute = 0x01;
  static const _headerSize = 24; // RAWINPUTHEADER на x64
  static const _vkF8 = 0x77;
  static const _modNoRepeat = 0x4000;
  static const _hotkeyId = 1;

  bool get supported => Platform.isWindows;

  void Function(RawKey)? _onKey;
  void Function(RawMouse)? _onMouse;
  void Function()? _onStop;

  static int _hwnd = 0;
  static RawInputListener? _active;
  static NativeCallable<win.WndProc>? _wndProc;

  bool get running => identical(_active, this);

  void start({
    required void Function(RawKey) onKey,
    required void Function(RawMouse) onMouse,
    required void Function() onStop,
  }) {
    if (!supported) return;
    _active?.stop();
    _onKey = onKey;
    _onMouse = onMouse;
    _onStop = onStop;
    _active = this;
    final hwnd = _ensureWindow();
    _register(hwnd, _ridevInputSink);
    win.registerHotKey(hwnd, _hotkeyId, _modNoRepeat, _vkF8);
  }

  void stop() {
    if (!running) return;
    _active = null;
    _onKey = _onMouse = _onStop = null;
    _register(0, _ridevRemove);
    win.unregisterHotKey(_hwnd, _hotkeyId);
  }

  static void _register(int hwnd, int flags) {
    final devices = calloc<win.RawInputDevice>(2);
    try {
      // Generic Desktop: мышь (2) и клавиатура (6).
      for (final (i, usage) in [2, 6].indexed) {
        devices[i]
          ..usUsagePage = 0x01
          ..usUsage = usage
          ..dwFlags = flags
          ..hwndTarget = hwnd;
      }
      win.registerRawInputDevices(devices, 2, sizeOf<win.RawInputDevice>());
    } finally {
      calloc.free(devices);
    }
  }

  static int _ensureWindow() {
    if (_hwnd != 0) return _hwnd;
    _wndProc = NativeCallable<win.WndProc>.isolateLocal(
      _windowProc,
      exceptionalReturn: 0,
    );
    final className = 'BloxAwysRawInput'.toNativeUtf16();
    final wc = calloc<win.WndClassEx>();
    try {
      final instance = win.getModuleHandle(nullptr);
      wc.ref
        ..cbSize = sizeOf<win.WndClassEx>()
        ..lpfnWndProc = _wndProc!.nativeFunction
        ..hInstance = instance
        ..lpszClassName = className;
      win.registerClassEx(wc);
      _hwnd = win.createWindowEx(
        0,
        className,
        className,
        0,
        0,
        0,
        0,
        0,
        _hwndMessage,
        0,
        instance,
        nullptr,
      );
    } finally {
      // Имя класса Windows копирует при регистрации.
      calloc.free(wc);
      calloc.free(className);
    }
    return _hwnd;
  }

  static int _windowProc(int hwnd, int msg, int wParam, int lParam) {
    if (msg == _wmInput) {
      _active?._handleInput(lParam);
    } else if (msg == _wmHotkey && wParam == _hotkeyId) {
      _active?._onStop?.call();
      return 0;
    }
    return win.defWindowProc(hwnd, msg, wParam, lParam);
  }

  void _handleInput(int rawInput) {
    final size = calloc<Uint32>();
    Pointer<Uint8> data = nullptr;
    try {
      win.getRawInputData(rawInput, _ridInput, nullptr, size, _headerSize);
      if (size.value == 0) return;
      data = calloc<Uint8>(size.value);
      if (win.getRawInputData(rawInput, _ridInput, data, size, _headerSize) ==
          0xFFFFFFFF) {
        return;
      }
      final bytes = data.asTypedList(size.value).buffer.asByteData();
      final type = bytes.getUint32(0, Endian.little);
      // У ввода от SendInput нет устройства.
      final physical = bytes.getUint64(8, Endian.little) != 0;
      if (type == _rimTypeKeyboard) {
        final makeCode = bytes.getUint16(_headerSize, Endian.little);
        final flags = bytes.getUint16(_headerSize + 2, Endian.little);
        final vKey = bytes.getUint16(_headerSize + 6, Endian.little);
        // 0xFF — служебные «фальшивые» клавиши.
        if (makeCode == 0 || vKey == 0xFF) return;
        _onKey?.call(
          RawKey(
            scanCode: makeCode,
            extended: flags & _riKeyE0 != 0,
            down: flags & _riKeyBreak == 0,
            physical: physical,
          ),
        );
      } else if (type == _rimTypeMouse) {
        final moveFlags = bytes.getUint16(_headerSize, Endian.little);
        final buttonFlags = bytes.getUint16(_headerSize + 4, Endian.little);
        final buttonData = bytes.getInt16(_headerSize + 6, Endian.little);
        final absolute = moveFlags & _mouseMoveAbsolute != 0;
        _onMouse?.call(
          RawMouse(
            dx: absolute ? 0 : bytes.getInt32(_headerSize + 12, Endian.little),
            dy: absolute ? 0 : bytes.getInt32(_headerSize + 16, Endian.little),
            buttonFlags: buttonFlags,
            wheel: buttonFlags & RawMouse.wheelFlag != 0 ? buttonData : 0,
            physical: physical,
          ),
        );
      }
    } finally {
      calloc.free(size);
      if (data != nullptr) calloc.free(data);
    }
  }
}
