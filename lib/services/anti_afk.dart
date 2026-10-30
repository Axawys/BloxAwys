import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import 'roblox_windows.dart';

/// Не даёт Roblox отключить за бездействие: раз в [AntiAfkSettings.intervalMinutes]
/// нажимает клавиши во всех окнах Roblox.
class AntiAfk extends ChangeNotifier {
  AntiAfk(this._windows, {bool Function()? isBusy})
    : _isBusy = isBusy ?? (() => false);

  final RobloxWindows _windows;

  /// Идёт запись или проигрывание макроса: нажатия не нужны и помешают.
  final bool Function() _isBusy;

  /// Если пользователь за компьютером, следующая попытка через столько.
  static const _retryDelay = Duration(seconds: 30);

  AntiAfkSettings _settings = const AntiAfkSettings();
  Timer? _timer;

  /// Порядок клавиш чередуется, чтобы небольшие смещения
  /// камеры или персонажа не накапливались.
  var _reverse = false;

  /// Когда будет следующее нажатие; null, если анти-AFK выключен.
  DateTime? nextRunAt;

  bool get supported => _windows.supported;

  void apply(AntiAfkSettings settings) {
    _settings = settings;
    _schedule(settings.enabled && supported ? _interval : null);
  }

  Duration get _interval => Duration(minutes: _settings.intervalMinutes);

  void _schedule(Duration? delay) {
    _timer?.cancel();
    _timer = delay == null ? null : Timer(delay, _run);
    nextRunAt = delay == null ? null : DateTime.now().add(delay);
    notifyListeners();
  }

  Future<void> _run() async {
    if (_isBusy() ||
        _settings.respectUserActivity &&
            _windows.userActiveWithin(_retryDelay)) {
      _schedule(_retryDelay);
      return;
    }
    _reverse = !_reverse;
    try {
      await _windows.pressInAll(_tapsFor(_settings.action));
    } finally {
      if (_settings.enabled) _schedule(_interval);
    }
  }

  List<KeyTap> _tapsFor(AntiAfkAction action) {
    final taps = switch (action) {
      AntiAfkAction.camera => [KeyTap.left, KeyTap.right],
      AntiAfkAction.strafe => [KeyTap.a, KeyTap.d],
      AntiAfkAction.jump => [KeyTap.space],
    };
    return _reverse ? taps.reversed.toList() : taps;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
