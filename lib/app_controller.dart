import 'package:flutter/foundation.dart';

import 'models/account.dart';
import 'services/account_store.dart';
import 'services/multi_instance.dart';
import 'services/roblox_api.dart';
import 'services/roblox_launcher.dart';

class AppController extends ChangeNotifier {
  AppController({AccountStore? store, RobloxApi? api, RobloxLauncher? launcher})
    : _store = store ?? AccountStore(),
      _api = api ?? RobloxApi(),
      _launcher = launcher ?? RobloxLauncher();

  final AccountStore _store;
  final RobloxApi _api;
  final RobloxLauncher _launcher;

  List<Account> accounts = [];
  final Set<int> launching = {};
  bool loaded = false;
  MultiInstanceStatus multiInstance = MultiInstanceStatus.unsupported;

  bool get robloxInstalled => _launcher.exePath != null;

  Future<void> init() async {
    multiInstance = MultiInstance.enable();
    accounts = await _store.load();
    loaded = true;
    notifyListeners();
    _refreshAvatars();
  }

  void recheckRoblox() {
    _launcher.refresh();
    notifyListeners();
  }

  Future<void> _refreshAvatars() async {
    try {
      final urls = await _api.getHeadshots(
        accounts.map((a) => a.userId).toList(),
      );
      if (urls.isEmpty) return;
      accounts = [
        for (final a in accounts) a.copyWith(avatarUrl: urls[a.userId]),
      ];
      notifyListeners();
      await _store.save(accounts);
    } catch (_) {
      // Аватары не критичны: без сети просто останутся старые.
    }
  }

  /// Сохраняет аккаунт по cookie из окна входа. Если такой аккаунт уже есть,
  /// обновляет его cookie (повторный вход).
  Future<Account> addFromCookie(String cookie) async {
    final user = await _api.getAuthenticatedUser(cookie);
    final avatars = await _api
        .getHeadshots([user.id])
        .catchError((_) => <int, String>{});
    final account = Account(
      userId: user.id,
      username: user.name,
      displayName: user.displayName,
      cookie: cookie,
      avatarUrl: avatars[user.id],
    );
    final index = accounts.indexWhere((a) => a.userId == user.id);
    accounts = [...accounts];
    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    notifyListeners();
    await _store.save(accounts);
    return account;
  }

  Future<void> remove(Account account) async {
    accounts = accounts.where((a) => a.userId != account.userId).toList();
    notifyListeners();
    await _store.save(accounts);
  }

  Future<void> launch(Account account, {int? placeId}) async {
    launching.add(account.userId);
    notifyListeners();
    try {
      final AuthTicket ticket;
      try {
        ticket = await _api.getAuthTicket(account.cookie);
      } on RobloxAuthException {
        await _update(account.userId, (a) => a.copyWith(needsRelogin: true));
        rethrow;
      }
      if (ticket.rotatedCookie != null || account.needsRelogin) {
        await _update(
          account.userId,
          (a) => a.copyWith(cookie: ticket.rotatedCookie, needsRelogin: false),
        );
      }
      await _launcher.launch(ticket: ticket.ticket, placeId: placeId);
    } finally {
      launching.remove(account.userId);
      notifyListeners();
    }
  }

  /// Запускает аккаунты по очереди: пауза нужна, чтобы окна успели
  /// стартовать и не мешали друг другу. Ошибки по отдельным аккаунтам
  /// собираются и возвращаются, остальные аккаунты всё равно запускаются.
  Future<Map<Account, Object>> launchMany(
    List<Account> list, {
    int? placeId,
  }) async {
    final errors = <Account, Object>{};
    for (var i = 0; i < list.length; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(seconds: 2));
      try {
        await launch(list[i], placeId: placeId);
      } catch (e) {
        errors[list[i]] = e;
      }
    }
    return errors;
  }

  Future<void> _update(int userId, Account Function(Account) change) async {
    accounts = [for (final a in accounts) a.userId == userId ? change(a) : a];
    notifyListeners();
    await _store.save(accounts);
  }
}
