import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/account.dart';
import '../services/multi_instance.dart';
import '../services/roblox_launcher.dart';
import 'login_page.dart';

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
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
          ?action,
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
          'Roblox был открыт до запуска BloxAwys. Закройте его окна и '
          'перезапустите клиент, иначе несколько окон не откроются.',
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
    required this.onSelected,
    required this.onLaunch,
    required this.onRelogin,
    required this.onRemove,
  });

  final Account account;
  final bool selected;
  final bool launching;
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
                    Text(
                      account.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
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
