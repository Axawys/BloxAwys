import 'dart:ffi';

import 'package:bloxawys/models/settings.dart';
import 'package:bloxawys/services/anti_afk.dart';
import 'package:bloxawys/services/roblox_windows.dart';
import 'package:bloxawys/services/win32.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWindows extends RobloxWindows {
  @override
  bool get supported => true;
}

void main() {
  test('размеры структур WinAPI совпадают с x64 Windows', () {
    // SendInput молча ничего не делает, если размер INPUT неверный.
    expect(sizeOf<Input>(), 40);
    expect(sizeOf<LastInputInfo>(), 8);
  });

  test('настройки сохраняются и читаются', () {
    const settings = AppSettings(
      antiAfk: AntiAfkSettings(
        enabled: true,
        action: AntiAfkAction.strafe,
        intervalMinutes: 5,
        respectUserActivity: false,
      ),
    );
    final restored = AppSettings.fromJson(settings.toJson()).antiAfk;
    expect(restored.enabled, isTrue);
    expect(restored.action, AntiAfkAction.strafe);
    expect(restored.intervalMinutes, 5);
    expect(restored.respectUserActivity, isFalse);
  });

  test(
    'неизвестные значения в настройках заменяются на значения по умолчанию',
    () {
      final s = AntiAfkSettings.fromJson({
        'action': 'dance',
        'intervalMinutes': 25,
      });
      expect(s.action, AntiAfkAction.camera);
      expect(s.intervalMinutes, 10);
    },
  );

  test('анти-AFK планирует нажатие только когда включён', () {
    final antiAfk = AntiAfk(_FakeWindows());
    antiAfk.apply(const AntiAfkSettings());
    expect(antiAfk.nextRunAt, isNull);

    antiAfk.apply(const AntiAfkSettings(enabled: true, intervalMinutes: 5));
    final left = antiAfk.nextRunAt!.difference(DateTime.now());
    expect(left.inMinutes, inInclusiveRange(4, 5));

    antiAfk.apply(const AntiAfkSettings());
    expect(antiAfk.nextRunAt, isNull);
    antiAfk.dispose();
  });
}
