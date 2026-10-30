import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/account.dart';
import 'models/macro.dart';
import 'models/settings.dart';
import 'services/account_store.dart';
import 'services/anti_afk.dart';
import 'services/macro_player.dart';
import 'services/macro_recorder.dart';
import 'services/macro_store.dart';
import 'services/multi_instance.dart';
import 'services/raw_input.dart';
import 'services/roblox_api.dart';
import 'services/roblox_launcher.dart';
import 'services/roblox_windows.dart';
import 'services/settings_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    AccountStore? store,
    RobloxApi? api,
    RobloxLauncher? launcher,
    MultiInstance? instances,
    RobloxWindows? windows,
    SettingsStore? settingsStore,
    MacroStore? macroStore,
    MacroRecorder? recorder,
    MacroPlayer? player,
  }) : _store = store ?? AccountStore(),
       _api = api ?? RobloxApi(),
       _launcher = launcher ?? RobloxLauncher(),
       _instances = instances ?? MultiInstance(),
       _windows = windows ?? RobloxWindows(),
       _settingsStore = settingsStore ?? SettingsStore(),
       _macroStore = macroStore ?? MacroStore() {
    final input = RawInputListener();
    macroRecorder = recorder ?? MacroRecorder(_windows, input);
    macroPlayer = (player ?? MacroPlayer(_windows, input))
      ..addListener(notifyListeners);
    antiAfk = AntiAfk(
      _windows,
      isBusy: () => macroRecorder.recording || macroPlayer.running,
    )..addListener(notifyListeners);
  }

  final AccountStore _store;
  final RobloxApi _api;
  final RobloxLauncher _launcher;
  final MultiInstance _instances;
  final RobloxWindows _windows;
  final SettingsStore _settingsStore;
  final MacroStore _macroStore;
  late final AntiAfk antiAfk;
  late final MacroRecorder macroRecorder;
  late final MacroPlayer macroPlayer;

  List<Macro> macros = [];

  /// Какой макрос выбран для окна аккаунта.
  final Map<int, MacroChoice> _macroChoices = {};

  List<Account> accounts = [];
  final Set<int> launching = {};
  bool loaded = false;
  MultiInstanceStatus multiInstance = MultiInstanceStatus.unsupported;
  bool closingRoblox = false;
  AppSettings settings = const AppSettings();

  /// ID процессов Roblox, запущенных клиентом, по аккаунтам.
  final Map<int, int> _running = {};
  Timer? _runningWatch;

  bool get robloxInstalled => _launcher.exePath != null;

  /// Окно Roblox этого аккаунта открыто.
  bool isRunning(Account account) => _running.containsKey(account.userId);

  bool get anyRunning => _running.isNotEmpty;

  /// Аккаунты с открытым окном Roblox, в порядке списка.
  List<Account> get runningAccounts =>
      accounts.where((a) => _running.containsKey(a.userId)).toList();

  Future<void> init() async {
    multiInstance = _instances.enable();
    settings = await _settingsStore.load();
    antiAfk.apply(settings.antiAfk);
    macros = await _macroStore.load();
    accounts = await _store.load();
    loaded = true;
    notifyListeners();
    _refreshAvatars();
  }

  /// Закрывает Roblox, открытый до клиента (например, из автозагрузки),
  /// чтобы заработали несколько окон.
  Future<void> closeOtherClients() async {
    closingRoblox = true;
    notifyListeners();
    try {
      multiInstance = await _instances.closeRobloxAndEnable();
    } finally {
      closingRoblox = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    antiAfk.apply(value.antiAfk);
    notifyListeners();
    await _settingsStore.save(value);
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

  /// Записывает макрос в окне аккаунта до нажатия F8 и возвращает его
  /// несохранённым; null — запись пустая или отменена.
  Future<Macro?> recordMacro(Account account) async {
    final pid = _running[account.userId];
    if (pid == null) {
      throw MacroException('Окно Roblox этого аккаунта не открыто');
    }
    final recording = macroRecorder.record(
      pid: pid,
      mouseMovement: settings.macros.recordMouseMovement,
    );
    notifyListeners();
    try {
      return await recording;
    } finally {
      final own = _windows.ownWindow();
      if (own != null) _windows.focus(own);
      notifyListeners();
    }
  }

  void stopRecording() => macroRecorder.stop();

  Future<void> addMacro(Macro macro, String name) async {
    macros = [...macros, macro.copyWith(name: name)];
    notifyListeners();
    await _macroStore.save(macros);
  }

  Future<void> renameMacro(Macro macro, String name) async {
    macros = [
      for (final m in macros) m.id == macro.id ? m.copyWith(name: name) : m,
    ];
    notifyListeners();
    await _macroStore.save(macros);
  }

  Future<void> deleteMacro(Macro macro) async {
    macros = macros.where((m) => m.id != macro.id).toList();
    _macroChoices.removeWhere((_, c) => c.macroId == macro.id);
    notifyListeners();
    await _macroStore.save(macros);
  }

  MacroChoice macroChoiceFor(Account account) =>
      _macroChoices[account.userId] ?? const MacroChoice();

  void setMacroChoice(Account account, MacroChoice choice) {
    _macroChoices[account.userId] = choice;
    notifyListeners();
  }

  /// Запускает выбранные макросы в окнах аккаунтов. Возвращает аккаунты,
  /// чьи окна не нашлись.
  List<Account> startMacros() {
    final assignments = <MacroAssignment>[];
    for (final account in runningAccounts) {
      final choice = macroChoiceFor(account);
      final macro = macros.where((m) => m.id == choice.macroId).firstOrNull;
      if (macro == null) continue;
      assignments.add(
        MacroAssignment(
          userId: account.userId,
          pid: _running[account.userId]!,
          macro: macro,
          loop: choice.loop,
        ),
      );
    }
    final missing = macroPlayer.start(
      assignments,
      stopOnUserInput: settings.macros.stopOnUserInput,
    );
    return accounts.where((a) => missing.contains(a.userId)).toList();
  }

  void stopMacros() => macroPlayer.stop();

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
      final pid = await _launcher.launch(
        ticket: ticket.ticket,
        placeId: placeId,
      );
      _running[account.userId] = pid;
      _runningWatch ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkRunning(),
      );
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

  /// Убирает отметку «в игре» у аккаунтов, чьи окна Roblox закрыли.
  void _checkRunning() {
    final alive = _windows.robloxPids().toSet();
    final before = _running.length;
    _running.removeWhere((_, pid) => !alive.contains(pid));
    if (_running.isEmpty) {
      _runningWatch?.cancel();
      _runningWatch = null;
    }
    if (_running.length != before) notifyListeners();
  }

  Future<void> _update(int userId, Account Function(Account) change) async {
    accounts = [for (final a in accounts) a.userId == userId ? change(a) : a];
    notifyListeners();
    await _store.save(accounts);
  }
}

/// Выбор макроса для окна аккаунта.
class MacroChoice {
  const MacroChoice({this.macroId, this.loop = true});

  final String? macroId;

  /// Повторять по кругу, пока не остановят.
  final bool loop;
}
