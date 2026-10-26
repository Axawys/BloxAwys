import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

enum MultiInstanceStatus {
  /// Объекты созданы, можно запускать несколько окон.
  enabled,

  /// Roblox уже был запущен до клиента: первое окно нужно закрыть,
  /// иначе следующий запуск закроет его.
  robloxAlreadyRunning,

  /// Не Windows.
  unsupported,
}

/// Позволяет запускать несколько копий Roblox одновременно.
///
/// При старте Roblox проверяет именованные объекты ядра `ROBLOX_singletonMutex`
/// и `ROBLOX_singletonEvent` и, если находит их, считает себя второй копией.
/// Клиент сам создаёт эти объекты (оба как мьютексы, так делают
/// Roblox Account Manager и MultiBloxy) и держит их, пока открыт.
/// Если клиент закрыть, новые окна снова будут закрывать старые.
class MultiInstance {
  static const _names = ['ROBLOX_singletonMutex', 'ROBLOX_singletonEvent'];
  static const _synchronize = 0x00100000;

  static final _handles = <Pointer<Void>>[];
  static MultiInstanceStatus? _status;

  static MultiInstanceStatus enable() {
    if (_status != null) return _status!;
    if (!Platform.isWindows) return _status = MultiInstanceStatus.unsupported;

    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final openMutex = kernel32
        .lookupFunction<
          Pointer<Void> Function(Uint32, Int32, Pointer<Utf16>),
          Pointer<Void> Function(int, int, Pointer<Utf16>)
        >('OpenMutexW');
    final createMutex = kernel32
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Utf16>),
          Pointer<Void> Function(Pointer<Void>, int, Pointer<Utf16>)
        >('CreateMutexW');
    final openEvent = kernel32
        .lookupFunction<
          Pointer<Void> Function(Uint32, Int32, Pointer<Utf16>),
          Pointer<Void> Function(int, int, Pointer<Utf16>)
        >('OpenEventW');
    final closeHandle = kernel32
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('CloseHandle');

    var robloxRunning = false;
    for (final name in _names) {
      final nativeName = name.toNativeUtf16();
      try {
        // Если объект уже существует, его создал запущенный Roblox
        // (или другой лаунчер вроде Bloxstrap).
        for (final open in [openMutex, openEvent]) {
          final existing = open(_synchronize, 0, nativeName);
          if (existing != nullptr) {
            robloxRunning = true;
            closeHandle(existing);
          }
        }
        final handle = createMutex(nullptr, 1, nativeName);
        if (handle != nullptr) _handles.add(handle);
      } finally {
        calloc.free(nativeName);
      }
    }

    return _status = robloxRunning
        ? MultiInstanceStatus.robloxAlreadyRunning
        : MultiInstanceStatus.enabled;
  }
}
