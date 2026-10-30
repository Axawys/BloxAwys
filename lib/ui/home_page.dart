import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/account.dart';
import '../services/multi_instance.dart';
import '../services/roblox_launcher.dart';
import 'login_page.dart';
import 'macros_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _selected = <int>{};
  final _placeController = TextEditingController();

  AppController get _c => widget.controller;

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  int? _placeIdOrWarn() {
    final text = _placeController.text;
    final id = parsePlaceId(text);
    if (text.trim().isNotEmpty && id == null) {
      _snack('Не понял ссылку на игру — запускаю главный экран Roblox');
    }
    return id;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Вход → сохранение → сразу запуск под этим аккаунтом.
  Future<void> _loginAndLaunch() async {
    final cookie = await LoginPage.open(context);
    if (cookie == null || !mounted) return;
    try {
      final account = await _c.addFromCookie(cookie);
      _snack('Аккаунт ${account.displayName} сохранён, запускаю Roblox');
      await _c.launch(account, placeId: _placeIdOrWarn());
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _launch(Account account) async {
    if (account.needsRelogin) return _loginAndLaunch();
    try {
      await _c.launch(account, placeId: _placeIdOrWarn());
    } catch (e) {
      _snack('${account.displayName}: $e');
    }
  }

  Future<void> _launchSelected() async {
    final list = _c.accounts
        .where((a) => _selected.contains(a.userId))
        .toList();
    final errors = await _c.launchMany(list, placeId: _placeIdOrWarn());
    if (!mounted) return;
    if (errors.isEmpty) {
      setState(_selected.clear);
    } else {
      _snack(
        errors.entries
            .map((e) => '${e.key.displayName}: ${e.value}')
            .join('\n'),
      );
    }
  }

  Future<void> _closeOtherClients() async {
    await _c.closeOtherClients();
    if (!mounted) return;
    if (_c.multiInstance == MultiInstanceStatus.robloxAlreadyRunning) {
      _snack(
        'Не получилось: Roblox держит другая программа, например Bloxstrap. '
        'Закройте её и перезапустите BloxAwys.',
      );
    } else {
      _snack('Другие клиенты Roblox закрыты');
    }
  }

  Future<void> _confirmRemove(Account account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: Text(
          '${account.displayName} (@${account.username}) пропадёт из списка. '
          'Сам аккаунт Roblox не изменится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _selected.remove(account.userId);
      await _c.remove(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('BloxAwys'),
          actions: [
            if (_c.settings.macros.enabled)
              IconButton(
                tooltip: 'Макросы',
                onPressed: () => MacrosPage.open(context, _c),
                icon: const Icon(Icons.keyboard_alt_outlined),
              ),
            IconButton(
              tooltip: 'Настройки',
              onPressed: () => SettingsPage.open(context, _c),
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Добавить аккаунт',
              onPressed: _loginAndLaunch,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
        body: !_c.loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._buildWarnings(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _placeController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.sports_esports_outlined),
                        labelText: 'Игра (необязательно)',
                        hintText: 'Ссылка или Place ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_c.macroPlayer.running)
                    _MacrosStatus(
                      onTap: () => MacrosPage.open(context, _c),
                      onStop: _c.stopMacros,
                    ),
                  if (_c.antiAfk.nextRunAt != null)
                    _AntiAfkStatus(
                      nextRunAt: _c.antiAfk.nextRunAt!,
                      robloxRunning: _c.anyRunning,
                      onTap: () => SettingsPage.open(context, _c),
                    ),
                  Expanded(
                    child: _c.accounts.isEmpty ? _buildEmpty() : _buildList(),
                  ),
                ],
              ),
        bottomNavigationBar: _selected.isEmpty ? null : _buildLaunchBar(),
      ),
    );
  }

  List<Widget> _buildWarnings() {
    final scheme = Theme.of(context).colorScheme;
    Widget banner(String text, {Widget? action}) => Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_rounded,
              color: scheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text(
                    text,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                if (action != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButtonTheme(
                      data: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onErrorContainer,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: action,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return [
      if (!_c.robloxInstalled)
        banner(
          'Roblox не установлен. Установите его с roblox.com.',
          action: TextButton(
            onPressed: _c.recheckRoblox,
            child: const Text('Проверить'),
          ),
        ),
      if (_c.multiInstance == MultiInstanceStatus.robloxAlreadyRunning)
        banner(
          'Roblox уже запущен, например из автозагрузки. Пока он открыт, '
          'несколько окон не откроются.',
          action: _c.closingRoblox
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : TextButton(
                  onPressed: _closeOtherClients,
                  child: const Text('Закрыть другие клиенты'),
                ),
        ),
    ];
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              'Войдите в аккаунт — он сохранится здесь, и в следующий раз '
              'Roblox запустится в один клик.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loginAndLaunch,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Войти и запустить Roblox'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final account in _c.accounts)
          _AccountTile(
            account: account,
            selected: _selected.contains(account.userId),
            launching: _c.launching.contains(account.userId),
            running: _c.isRunning(account),
            onSelected: (value) => setState(
              () => value
                  ? _selected.add(account.userId)
                  : _selected.remove(account.userId),
            ),
            onLaunch: () => _launch(account),
            onRelogin: _loginAndLaunch,
            onRemove: () => _confirmRemove(account),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loginAndLaunch,
          icon: const Icon(Icons.add),
          label: const Text('Добавить аккаунт'),
        ),
      ],
    );
  }

  Widget _buildLaunchBar() {
    final busy = _c.launching.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('Сбросить'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _launchSelected,
                icon: const Icon(Icons.play_arrow),
                label: Text('Запустить выбранные (${_selected.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.launching,
    required this.running,
    required this.onSelected,
    required this.onLaunch,
    required this.onRelogin,
    required this.onRemove,
  });

  final Account account;
  final bool selected;
  final bool launching;

  /// Окно Roblox этого аккаунта открыто.
  final bool running;
  final ValueChanged<bool> onSelected;
  final VoidCallback onLaunch;
  final VoidCallback onRelogin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onSelected(v ?? false),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundImage: account.avatarUrl == null
                    ? null
                    : NetworkImage(account.avatarUrl!),
                child: Text(account.displayName.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (running) ...[
                          const SizedBox(width: 8),
                          const _InGameBadge(),
                        ],
                      ],
                    ),
                    Text(
                      account.needsRelogin
                          ? 'Сессия истекла — нужно войти заново'
                          : '@${account.username}',
                      style: TextStyle(
                        color: account.needsRelogin
                            ? scheme.error
                            : scheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (launching)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                IconButton.filledTonal(
                  tooltip: account.needsRelogin ? 'Войти заново' : 'Запустить',
                  onPressed: onLaunch,
                  icon: Icon(
                    account.needsRelogin ? Icons.login : Icons.play_arrow,
                  ),
                ),
              PopupMenuButton<VoidCallback>(
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: onRelogin,
                    child: const Text('Войти заново'),
                  ),
                  PopupMenuItem(value: onRemove, child: const Text('Удалить')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InGameBadge extends StatelessWidget {
  const _InGameBadge();

  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'в игре',
        style: TextStyle(color: _green, fontSize: 12),
      ),
    );
  }
}

/// Полоска на главном экране, пока анти-AFK включён.
class _AntiAfkStatus extends StatefulWidget {
  const _AntiAfkStatus({
    required this.nextRunAt,
    required this.robloxRunning,
    required this.onTap,
  });

  final DateTime nextRunAt;
  final bool robloxRunning;
  final VoidCallback onTap;

  @override
  State<_AntiAfkStatus> createState() => _AntiAfkStatusState();
}

class _AntiAfkStatusState extends State<_AntiAfkStatus> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Оставшееся время пересчитывается без событий от контроллера.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String get _text {
    if (!widget.robloxRunning) return 'Анти-AFK включён · ждёт окон Roblox';
    final left = widget.nextRunAt.difference(DateTime.now());
    if (left.inSeconds < 60) {
      return 'Анти-AFK включён · нажатие меньше чем через минуту';
    }
    final minutes = (left.inSeconds / 60).ceil();
    return 'Анти-AFK включён · следующее нажатие через $minutes мин';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _text,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Полоска на главном экране, пока выполняются макросы.
class _MacrosStatus extends StatelessWidget {
  const _MacrosStatus({required this.onTap, required this.onStop});

  final VoidCallback onTap;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Icon(
                  Icons.keyboard_alt_outlined,
                  size: 20,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Макросы выполняются · F8 — остановить',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
                TextButton(
                  onPressed: onStop,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onTertiaryContainer,
                  ),
                  child: const Text('Стоп'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
