import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'roblox_windows.dart';
import 'win32.dart' as win;

/// Системная шапка окна клиента. Windows красит её по теме системы,
/// а тему клиента можно выбрать отдельно, поэтому цвет выставляется вручную.
class TitleBar {
  static const _dwmwaUseImmersiveDarkMode = 20;

  /// SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE |
  /// SWP_FRAMECHANGED: только перерисовать рамку.
  static const _redrawFrame = 0x0001 | 0x0002 | 0x0004 | 0x0010 | 0x0020;

  /// Делает шапку тёмной или светлой. false — окно ещё не показано.
  static bool setDark(bool dark) {
    if (!Platform.isWindows) return true;
    final hwnd = RobloxWindows().ownWindow();
    if (hwnd == null) return false;
    final value = calloc<Int32>()..value = dark ? 1 : 0;
    try {
      win.dwmSetWindowAttribute(
        hwnd,
        _dwmwaUseImmersiveDarkMode,
        value,
        sizeOf<Int32>(),
      );
      win.setWindowPos(hwnd, 0, 0, 0, 0, 0, _redrawFrame);
    } finally {
      calloc.free(value);
    }
    return true;
  }
}
