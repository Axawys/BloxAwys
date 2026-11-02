import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'win32.dart' as win;

/// Как выглядит плашка.
enum IndicatorStyle {
  /// Синяя: клиент ждёт F8.
  waiting,

  /// Красная: идёт запись макроса.
  recording,

  /// Зелёная: выполняются макросы.
  playing,
}

/// Плашка у верхнего края окна Roblox: показывает, что клиент ждёт F8,
/// записывает или выполняет макросы, чтобы ради этого не переключаться
/// в BloxAwys.
///
/// Это отдельное окно поверх остальных. Оно не забирает фокус и пропускает
/// клики насквозь, поэтому игре не мешает. Плашка стоит над активным окном,
/// пока для него `over` возвращает true, и прячется в остальное время.
class RecordingIndicator {
  static const _wsPopup = 0x80000000;
  static const _wsExTopmost = 0x00000008;
  static const _wsExTransparent = 0x00000020;
  static const _wsExToolWindow = 0x00000080;
  static const _wsExLayered = 0x00080000;
  static const _wsExNoActivate = 0x08000000;
  static const _lwaAlpha = 0x2;
  static const _hwndTopmost = -1;
  static const _swpNoActivate = 0x0010;
  static const _swpShowWindow = 0x0040;
  static const _swHide = 0;
  static const _wmPaint = 0x000F;
  static const _bkTransparent = 1;
  static const _dtCenterSingleLine = 0x1 | 0x4 | 0x20;
  static const _fwSemibold = 600;
  static const _antialiasedQuality = 4;

  /// Цвета в формате COLORREF (0x00BBGGRR).
  static const _blue = 0x00EB6325;
  static const _red = 0x002626DC;
  static const _green = 0x003D8A16;
  static const _white = 0x00FFFFFF;

  /// Размеры при масштабе 100 %.
  static const _width = 320;
  static const _height = 34;
  static const _marginTop = 12;
  static const _fontSize = 15;

  static const _tick = Duration(milliseconds: 150);

  bool get supported => Platform.isWindows;

  Timer? _timer;
  bool Function(int hwnd) _over = _never;
  bool _visible = false;
  double _scale = 0;

  static int _hwnd = 0;
  static NativeCallable<win.WndProc>? _wndProc;
  static String _text = '';
  static int _color = _blue;
  static int _font = 0;

  static bool _never(int hwnd) => false;

  /// Показывает [text] над активным окном, если [over] его принимает.
  void show(
    String text, {
    required IndicatorStyle style,
    required bool Function(int hwnd) over,
  }) {
    if (!supported) return;
    _ensureWindow();
    _text = text;
    _color = switch (style) {
      IndicatorStyle.waiting => _blue,
      IndicatorStyle.recording => _red,
      IndicatorStyle.playing => _green,
    };
    _over = over;
    win.invalidateRect(_hwnd, nullptr, 1);
    _timer ??= Timer.periodic(_tick, (_) => _follow());
    _follow();
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    _over = _never;
    _setHidden();
  }

  void _follow() {
    final target = win.getForegroundWindow();
    if (target == 0 || win.isIconic(target) != 0 || !_over(target)) {
      _setHidden();
      return;
    }
    final dpi = win.getDpiForWindow(target);
    final scale = dpi == 0 ? 1.0 : dpi / 96;
    final width = (_width * scale).round();
    final height = (_height * scale).round();
    if (scale != _scale) _rescale(scale, width, height);

    final rect = calloc<win.Rect>();
    final origin = calloc<win.Point>();
    try {
      win.getClientRect(target, rect);
      win.clientToScreen(target, origin);
      final x = origin.ref.x + (rect.ref.right - width) ~/ 2;
      final y = origin.ref.y + (_marginTop * scale).round();
      // Каждый раз заново, чтобы плашка оставалась поверх окна Roblox,
      // даже если оно поднялось наверх.
      win.setWindowPos(
        _hwnd,
        _hwndTopmost,
        x,
        y,
        width,
        height,
        _swpNoActivate | _swpShowWindow,
      );
      _visible = true;
    } finally {
      calloc.free(rect);
      calloc.free(origin);
    }
  }

  void _setHidden() {
    if (!_visible) return;
    win.showWindow(_hwnd, _swHide);
    _visible = false;
  }

  /// Шрифт и скруглённые углы под масштаб монитора.
  void _rescale(double scale, int width, int height) {
    _scale = scale;
    if (_font != 0) win.deleteObject(_font);
    final face = 'Segoe UI'.toNativeUtf16();
    try {
      _font = win.createFont(
        -(_fontSize * scale).round(),
        0,
        0,
        0,
        _fwSemibold,
        0,
        0,
        0,
        1, // DEFAULT_CHARSET
        0,
        0,
        _antialiasedQuality,
        0,
        face,
      );
    } finally {
      calloc.free(face);
    }
    // Регион переходит во владение окна, удалять его не нужно.
    win.setWindowRgn(
      _hwnd,
      win.createRoundRectRgn(0, 0, width + 1, height + 1, height, height),
      1,
    );
    win.invalidateRect(_hwnd, nullptr, 1);
  }

  static void _ensureWindow() {
    if (_hwnd != 0) return;
    _wndProc = NativeCallable<win.WndProc>.isolateLocal(
      _windowProc,
      exceptionalReturn: 0,
    );
    final className = 'BloxAwysRecordingIndicator'.toNativeUtf16();
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
        _wsExTopmost |
            _wsExTransparent |
            _wsExToolWindow |
            _wsExLayered |
            _wsExNoActivate,
        className,
        className,
        _wsPopup,
        0,
        0,
        _width,
        _height,
        0,
        0,
        instance,
        nullptr,
      );
      win.setLayeredWindowAttributes(_hwnd, 0, 235, _lwaAlpha);
    } finally {
      calloc.free(wc);
      calloc.free(className);
    }
  }

  static int _windowProc(int hwnd, int msg, int wParam, int lParam) {
    if (msg == _wmPaint) {
      _paint(hwnd);
      return 0;
    }
    return win.defWindowProc(hwnd, msg, wParam, lParam);
  }

  static void _paint(int hwnd) {
    final paint = calloc<Uint8>(win.paintStructSize);
    final rect = calloc<win.Rect>();
    final text = _text.toNativeUtf16();
    try {
      final hdc = win.beginPaint(hwnd, paint);
      win.getClientRect(hwnd, rect);
      final brush = win.createSolidBrush(_color);
      win.fillRect(hdc, rect, brush);
      win.deleteObject(brush);
      final previousFont = _font == 0 ? 0 : win.selectObject(hdc, _font);
      win.setBkMode(hdc, _bkTransparent);
      win.setTextColor(hdc, _white);
      win.drawText(hdc, text, -1, rect, _dtCenterSingleLine);
      if (_font != 0) win.selectObject(hdc, previousFont);
      win.endPaint(hwnd, paint);
    } finally {
      calloc.free(paint);
      calloc.free(rect);
      calloc.free(text);
    }
  }
}
