import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'main.dart';
import 'models/account.dart';
import 'services/account_store.dart';
import 'services/roblox_api.dart';
import 'services/roblox_launcher.dart';

/// Демо-режим для проверки интерфейса без Windows: аккаунты ненастоящие,
/// хранятся в памяти, «запуск» Roblox только изображает работу.
/// Аватары загружаются настоящие, по публичным ID пользователей Roblox.
///
/// Запуск: `flutter run -d linux -t lib/main_demo.dart` или `./run_linux.sh`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    store: _MemoryAccountStore(),
    api: _DemoRobloxApi(),
    launcher: _DemoRobloxLauncher(),
  )..init();
  // Тема и шрифты как на Windows (Segoe UI, если он установлен).
  runApp(BloxAwysApp(controller: controller, platform: TargetPlatform.windows));
}

class _MemoryAccountStore extends AccountStore {
  List<Account> _accounts = [
    Account(
      userId: 156,
      username: 'builderman',
      displayName: 'builderman',
      cookie: 'demo',
    ),
    Account(userId: 1, username: 'Roblox', displayName: 'Roblox', cookie: 'demo'),
    Account(
      userId: 261,
      username: 'Shedletsky',
      displayName: 'Shedletsky',
      cookie: 'demo',
      needsRelogin: true,
    ),
  ];

  @override
  Future<List<Account>> load() async => _accounts;

  @override
  Future<void> save(List<Account> accounts) async => _accounts = accounts;
}

class _DemoRobloxApi extends RobloxApi {
  @override
  Future<AuthTicket> getAuthTicket(String cookie) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return AuthTicket('demo', null);
  }
}

class _DemoRobloxLauncher extends RobloxLauncher {
  @override
  String? get exePath => 'RobloxPlayerBeta.exe';

  @override
  Future<void> launch({required String ticket, int? placeId}) =>
      Future<void>.delayed(const Duration(seconds: 1));
}
