import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Минимальные привязки WinAPI, которые нужны клиенту.
///
/// Библиотеки открываются при первом обращении, поэтому импортировать файл
/// можно на любой платформе, а вызывать функции — только на Windows.

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _user32 = DynamicLibrary.open('user32.dll');

const synchronize = 0x00100000;
const processTerminate = 0x0001;
const _snapProcess = 0x00000002;
const _robloxPlayerExe = 'robloxplayerbeta.exe';

final openMutex = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Uint32, Int32, Pointer<Utf16>),
      Pointer<Void> Function(int, int, Pointer<Utf16>)
    >('OpenMutexW');
final createMutex = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Utf16>),
      Pointer<Void> Function(Pointer<Void>, int, Pointer<Utf16>)
    >('CreateMutexW');
final openEvent = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Uint32, Int32, Pointer<Utf16>),
      Pointer<Void> Function(int, int, Pointer<Utf16>)
    >('OpenEventW');
final closeHandle = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CloseHandle',
    );
final openProcess = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Uint32, Int32, Uint32),
      Pointer<Void> Function(int, int, int)
    >('OpenProcess');
final terminateProcess = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)
    >('TerminateProcess');
final getTickCount = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetTickCount');
final getCurrentThreadId = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetCurrentThreadId');
final _createSnapshot = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Uint32, Uint32),
      Pointer<Void> Function(int, int)
    >('CreateToolhelp32Snapshot');
final _processFirst = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<_ProcessEntry32W>),
      int Function(Pointer<Void>, Pointer<_ProcessEntry32W>)
    >('Process32FirstW');
final _processNext = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<_ProcessEntry32W>),
      int Function(Pointer<Void>, Pointer<_ProcessEntry32W>)
    >('Process32NextW');

typedef EnumWindowsProc = Int32 Function(IntPtr hwnd, IntPtr lParam);

final enumWindows = _user32
    .lookupFunction<
      Int32 Function(Pointer<NativeFunction<EnumWindowsProc>>, IntPtr),
      int Function(Pointer<NativeFunction<EnumWindowsProc>>, int)
    >('EnumWindows');
final getWindowThreadProcessId = _user32
    .lookupFunction<
      Uint32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetWindowThreadProcessId');
final isWindowVisible = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'IsWindowVisible',
    );
final isIconic = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsIconic');
final getWindow = _user32
    .lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>(
      'GetWindow',
    );
final getForegroundWindow = _user32
    .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
final setForegroundWindow = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'SetForegroundWindow',
    );
final bringWindowToTop = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'BringWindowToTop',
    );
final showWindow = _user32
    .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
      'ShowWindow',
    );
final attachThreadInput = _user32
    .lookupFunction<
      Int32 Function(Uint32, Uint32, Int32),
      int Function(int, int, int)
    >('AttachThreadInput');
final sendInput = _user32
    .lookupFunction<
      Uint32 Function(Uint32, Pointer<Input>, Int32),
      int Function(int, Pointer<Input>, int)
    >('SendInput');
final getLastInputInfo = _user32
    .lookupFunction<
      Int32 Function(Pointer<LastInputInfo>),
      int Function(Pointer<LastInputInfo>)
    >('GetLastInputInfo');

typedef WndProc = IntPtr Function(
  IntPtr hwnd,
  Uint32 msg,
  IntPtr wParam,
  IntPtr lParam,
);

final getCurrentProcessId = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetCurrentProcessId');
final getModuleHandle = _kernel32
    .lookupFunction<
      IntPtr Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('GetModuleHandleW');
final registerClassEx = _user32
    .lookupFunction<
      Uint16 Function(Pointer<WndClassEx>),
      int Function(Pointer<WndClassEx>)
    >('RegisterClassExW');
final createWindowEx = _user32
    .lookupFunction<
      IntPtr Function(
        Uint32,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Uint32,
        Int32,
        Int32,
        Int32,
        Int32,
        IntPtr,
        IntPtr,
        IntPtr,
        Pointer<Void>,
      ),
      int Function(
        int,
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        Pointer<Void>,
      )
    >('CreateWindowExW');
final defWindowProc = _user32
    .lookupFunction<
      IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr),
      int Function(int, int, int, int)
    >('DefWindowProcW');
final registerRawInputDevices = _user32
    .lookupFunction<
      Int32 Function(Pointer<RawInputDevice>, Uint32, Uint32),
      int Function(Pointer<RawInputDevice>, int, int)
    >('RegisterRawInputDevices');
final getRawInputData = _user32
    .lookupFunction<
      Uint32 Function(IntPtr, Uint32, Pointer<Uint8>, Pointer<Uint32>, Uint32),
      int Function(int, int, Pointer<Uint8>, Pointer<Uint32>, int)
    >('GetRawInputData');
final registerHotKey = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Int32, Uint32, Uint32),
      int Function(int, int, int, int)
    >('RegisterHotKey');
final unregisterHotKey = _user32
    .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
      'UnregisterHotKey',
    );
final getCursorPos = _user32
    .lookupFunction<
      Int32 Function(Pointer<Point>),
      int Function(Pointer<Point>)
    >('GetCursorPos');
final setCursorPos = _user32
    .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
      'SetCursorPos',
    );
final screenToClient = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Point>),
      int Function(int, Pointer<Point>)
    >('ScreenToClient');
final clientToScreen = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Point>),
      int Function(int, Pointer<Point>)
    >('ClientToScreen');
final getClientRect = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Rect>),
      int Function(int, Pointer<Rect>)
    >('GetClientRect');

/// ID всех запущенных процессов RobloxPlayerBeta.exe.
List<int> robloxPlayerPids() {
  final pids = <int>[];
  final snapshot = _createSnapshot(_snapProcess, 0);
  // INVALID_HANDLE_VALUE
  if (snapshot.address == -1) return pids;
  final entry = calloc<_ProcessEntry32W>();
  try {
    entry.ref.dwSize = sizeOf<_ProcessEntry32W>();
    var ok = _processFirst(snapshot, entry);
    while (ok != 0) {
      if (entry.ref.exeName.toLowerCase() == _robloxPlayerExe) {
        pids.add(entry.ref.th32ProcessID);
      }
      ok = _processNext(snapshot, entry);
    }
  } finally {
    calloc.free(entry);
    closeHandle(snapshot);
  }
  return pids;
}

/// PROCESSENTRY32W из tlhelp32.h.
final class _ProcessEntry32W extends Struct {
  @Uint32()
  external int dwSize;
  @Uint32()
  external int cntUsage;
  @Uint32()
  external int th32ProcessID;
  @UintPtr()
  external int th32DefaultHeapID;
  @Uint32()
  external int th32ModuleID;
  @Uint32()
  external int cntThreads;
  @Uint32()
  external int th32ParentProcessID;
  @Int32()
  external int pcPriClassBase;
  @Uint32()
  external int dwFlags;
  @Array(260)
  external Array<Uint16> szExeFile;

  String get exeName {
    final codes = <int>[];
    for (var i = 0; i < 260 && szExeFile[i] != 0; i++) {
      codes.add(szExeFile[i]);
    }
    return String.fromCharCodes(codes);
  }
}

/// INPUT из winuser.h (используется только клавиатурная часть).
final class Input extends Struct {
  @Uint32()
  external int type;
  external InputUnion u;
}

final class InputUnion extends Union {
  external MouseInput mi;
  external KeybdInput ki;
}

/// Нужен только для правильного размера INPUT: MOUSEINPUT — самый большой
/// член объединения.
final class MouseInput extends Struct {
  @Int32()
  external int dx;
  @Int32()
  external int dy;
  @Uint32()
  external int mouseData;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @UintPtr()
  external int dwExtraInfo;
}

final class KeybdInput extends Struct {
  @Uint16()
  external int wVk;
  @Uint16()
  external int wScan;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @UintPtr()
  external int dwExtraInfo;
}

final class LastInputInfo extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int dwTime;
}

/// WNDCLASSEXW из winuser.h.
final class WndClassEx extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int style;
  external Pointer<NativeFunction<WndProc>> lpfnWndProc;
  @Int32()
  external int cbClsExtra;
  @Int32()
  external int cbWndExtra;
  @IntPtr()
  external int hInstance;
  @IntPtr()
  external int hIcon;
  @IntPtr()
  external int hCursor;
  @IntPtr()
  external int hbrBackground;
  external Pointer<Utf16> lpszMenuName;
  external Pointer<Utf16> lpszClassName;
  @IntPtr()
  external int hIconSm;
}

/// RAWINPUTDEVICE из winuser.h.
final class RawInputDevice extends Struct {
  @Uint16()
  external int usUsagePage;
  @Uint16()
  external int usUsage;
  @Uint32()
  external int dwFlags;
  @IntPtr()
  external int hwndTarget;
}

final class Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}
