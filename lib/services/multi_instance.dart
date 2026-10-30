import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'win32.dart';

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

  final _handles = <Pointer<Void>>[];
  MultiInstanceStatus? _status;

  MultiInstanceStatus enable() {
    if (_status != null) return _status!;
    if (!Platform.isWindows) return _status = MultiInstanceStatus.unsupported;

    // Если объекты уже существуют, их создал запущенный Roblox
    // (или другой лаунчер вроде Bloxstrap).
    final robloxRunning = _robloxObjectsExist();
    for (final name in _names) {
      final nativeName = name.toNativeUtf16();
      try {
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

  /// Закрывает запущенные копии Roblox и заново создаёт объекты.
  ///
  /// Свои дескрипторы закрываются заранее: пока они открыты, объекты
  /// Roblox не исчезнут и после завершения его процессов.
  Future<MultiInstanceStatus> closeRobloxAndEnable() async {
    if (!Platform.isWindows) return enable();
    for (final handle in _handles) {
      closeHandle(handle);
    }
    _handles.clear();
    _status = null;

    for (final pid in robloxPlayerPids()) {
      final process = openProcess(processTerminate, 0, pid);
      if (process != nullptr) {
        terminateProcess(process, 0);
        closeHandle(process);
      }
    }
    // Процесс завершается не мгновенно, а объекты исчезают только
    // вместе с последним дескриптором.
    for (var i = 0; i < 20 && _robloxObjectsExist(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return enable();
  }

  bool _robloxObjectsExist() {
    var exists = false;
    for (final name in _names) {
      final nativeName = name.toNativeUtf16();
      try {
        for (final open in [openMutex, openEvent]) {
          final existing = open(synchronize, 0, nativeName);
          if (existing != nullptr) {
            exists = true;
            closeHandle(existing);
          }
        }
      } finally {
        calloc.free(nativeName);
      }
    }
    return exists;
  }
}
