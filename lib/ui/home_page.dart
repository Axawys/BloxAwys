import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/account.dart';
import '../models/macro.dart';
import '../services/multi_instance.dart';
import '../services/roblox_launcher.dart';
import 'login_page.dart';
import 'macros_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _selected = <int>{};
  final _placeController = TextEditingController();
  bool _macrosWereRunning = false;

  AppController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.macroPlayer.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    _c.macroPlayer.removeListener(_onPlayerChanged);
    _placeController.dispose();
    super.dispose();
  }

  /// Сообщает, почему макросы остановились сами.
  void _onPlayerChanged() {
    final player = _c.macroPlayer;
    if (_macrosWereRunning && !player.running && player.stopReason != null) {
      _snack(player.stopReason!);
    }
    _macrosWereRunning = player.running;
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

  void _toggleAntiAfk() {
    final s = _c.settings;
    _c.updateSettings(
      s.copyWith(antiAfk: s.antiAfk.copyWith(enabled: !s.antiAfk.enabled)),
    );
  }

  Future<void> _recordMacro() => recordAndSaveMacro(context, _c);

  void _openMacros() => MacrosPage.open(context, _c);

  void _startMacros() {
    final missing = _c.startMacros();
    if (missing.isNotEmpty) {
      _snack(
        'Не нашлось окно Roblox: '
        '${missing.map((a) => a.displayName).join(', ')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        // Запущенный аккаунт второй раз не запускается, поэтому из выбора
        // для запуска он выпадает.
        _selected.removeWhere(
          (id) => _c.accounts.any((a) => a.userId == id && _c.isRunning(a)),
        );
        final antiAfkOn = _c.antiAfk.nextRunAt != null;
        final macrosOn = _c.settings.macros.enabled;
        return Scaffold(
          appBar: AppBar(
            title: const Text('BloxAwys'),
            actions: [
              if (_c.antiAfk.supported)
                IconButton(
                  tooltip: antiAfkOn
                      ? 'Анти-AFK включён — выключить'
                      : 'Анти-AFK выключен — включить',
                  onPressed: _toggleAntiAfk,
                  icon: Icon(
                    antiAfkOn ? Icons.shield : Icons.shield_outlined,
                    color: antiAfkOn ? AppColors.of(context).success : null,
                  ),
                ),
              IconButton(
                tooltip: 'Настройки',
                onPressed: () => SettingsPage.open(context, _c),
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 8),
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
                          hintText: 'Игра (необязательно): ссылка или Place ID',
                        ),
                      ),
                    ),
                    if (antiAfkOn)
                      _AntiAfkStatus(
                        nextRunAt: _c.antiAfk.nextRunAt!,
                        robloxRunning: _c.anyRunning,
                        onTap: () => SettingsPage.open(context, _c),
                      ),
                    if (_c.accounts.isNotEmpty) _buildCommandBar(),
                    Expanded(
                      child: _c.accounts.isEmpty ? _buildEmpty() : _buildList(),
                    ),
                  ],
                ),
          bottomNavigationBar: macrosOn && _c.accounts.isNotEmpty
              ? _MacroBar(
                  controller: _c,
                  onRecord: _recordMacro,
                  onStart: _startMacros,
                  onManage: _openMacros,
                )
              : null,
        );
      },
    );
  }

  List<Widget> _buildWarnings() {
    final scheme = Theme.of(context).colorScheme;
    Widget banner(String text, {Widget? action}) => Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
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

  /// Строка над списком: запуск выбранных и добавление аккаунта.
  Widget _buildCommandBar() {
    final theme = Theme.of(context);
    final busy = _c.launching.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (_selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Аккаунты · ${_c.accounts.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            FilledButton.icon(
              onPressed: busy ? null : _launchSelected,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text('Запустить выбранные (${_selected.length})'),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('Сбросить'),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: _loginAndLaunch,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Добавить'),
          ),
        ],
      ),
    );
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
    final player = _c.macroPlayer;
    final macrosOn = _c.settings.macros.enabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final account in _c.accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccountCard(
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
              macro: macrosOn && _c.isRunning(account)
                  ? _MacroPicker(
                      macros: _c.macros,
                      choice: _c.macroChoiceFor(account),
                      playing: player.isPlaying(account.userId),
                      loops: player.loopsOf(account.userId),
                      backward: player.isBackward(account.userId),
                      locked: player.active || _c.macroRecorder.active,
                      onChanged: (choice) => _c.setMacroChoice(account, choice),
                      onRecord: _recordMacro,
                      onManage: _openMacros,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.selected,
    required this.launching,
    required this.running,
    required this.onSelected,
    required this.onLaunch,
    required this.onRelogin,
    required this.onRemove,
    this.macro,
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

  /// Выбор макроса под строкой аккаунта.
  final Widget? macro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final light = theme.brightness == Brightness.light;
    // Пока аватар не загрузился, у каждого аккаунта свой цвет.
    final hue = (account.userId * 47 % 360).toDouble();

    return Card(
      color: selected ? colors.selectedCard : null,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colors.selectedCardBorder),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: running ? null : () => onSelected(!selected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: running ? null : (v) => onSelected(v ?? false),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: HSLColor.fromAHSL(
                      1,
                      hue,
                      light ? 0.7 : 0.3,
                      light ? 0.9 : 0.3,
                    ).toColor(),
                    foregroundColor: HSLColor.fromAHSL(
                      1,
                      hue,
                      light ? 0.55 : 0.8,
                      light ? 0.3 : 0.88,
                    ).toColor(),
                    foregroundImage: account.avatarUrl == null
                        ? null
                        : NetworkImage(account.avatarUrl!),
                    child: Text(
                      account.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                                : scheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (launching)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  // Окно уже открыто: второй запуск выбьет первую сессию.
                  else if (running)
                    const SizedBox.shrink()
                  else if (account.needsRelogin)
                    IconButton.outlined(
                      tooltip: 'Войти заново',
                      onPressed: onLaunch,
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      icon: const Icon(Icons.login),
                    )
                  else
                    IconButton.filled(
                      tooltip: 'Запустить',
                      onPressed: onLaunch,
                      icon: const Icon(Icons.play_arrow),
                    ),
                  PopupMenuButton<VoidCallback>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: onRelogin,
                        child: const Text('Войти заново'),
                      ),
                      PopupMenuItem(
                        value: onRemove,
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (macro != null) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 8, 12, 10),
                child: macro,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InGameBadge extends StatelessWidget {
  const _InGameBadge();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'в игре',
        style: TextStyle(
          color: colors.success,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

const _playModes = [
  (MacroPlayMode.once, Icons.arrow_forward, 'Один раз'),
  (MacroPlayMode.loop, Icons.repeat, 'По кругу'),
  (MacroPlayMode.pingPong, Icons.swap_horiz, 'Туда-обратно'),
];

/// Выбор макроса и режима в карточке запущенного аккаунта.
class _MacroPicker extends StatelessWidget {
  const _MacroPicker({
    required this.macros,
    required this.choice,
    required this.playing,
    required this.loops,
    required this.backward,
    required this.locked,
    required this.onChanged,
    required this.onRecord,
    required this.onManage,
  });

  final List<Macro> macros;
  final MacroChoice choice;
  final bool playing;
  final int loops;
  final bool backward;

  /// Макросы запущены или идёт запись: выбор менять нельзя.
  final bool locked;
  final ValueChanged<MacroChoice> onChanged;
  final VoidCallback onRecord;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selected = macros.where((m) => m.id == choice.macroId).firstOrNull;
    final (_, modeIcon, modeLabel) = _playModes.firstWhere(
      (m) => m.$1 == choice.mode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PopupMenuButton<VoidCallback>(
                enabled: !locked,
                tooltip: 'Макрос для этого окна',
                position: PopupMenuPosition.under,
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    height: 40,
                    value: () => onChanged(
                      MacroChoice(macroId: null, mode: choice.mode),
                    ),
                    child: _MenuRow(
                      checked: selected == null,
                      label: 'Без макроса',
                    ),
                  ),
                  for (final m in macros)
                    PopupMenuItem(
                      height: 40,
                      value: () => onChanged(
                        MacroChoice(macroId: m.id, mode: choice.mode),
                      ),
                      child: _MenuRow(
                        checked: selected?.id == m.id,
                        label: m.name,
                        trailing: formatMacroDuration(m.durationMs),
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    height: 40,
                    value: onRecord,
                    child: _MenuRow(
                      icon: Icons.fiber_manual_record,
                      iconColor: colors.record,
                      label: 'Записать новый…',
                    ),
                  ),
                  PopupMenuItem(
                    height: 40,
                    value: onManage,
                    child: const _MenuRow(
                      icon: Icons.edit_outlined,
                      label: 'Управление макросами…',
                    ),
                  ),
                ],
                child: _ComboBox(
                  label: selected?.name ?? 'Без макроса',
                  placeholder: selected == null,
                  enabled: !locked,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<MacroPlayMode>(
              enabled: !locked,
              tooltip: 'Как повторять',
              position: PopupMenuPosition.under,
              onSelected: (mode) =>
                  onChanged(MacroChoice(macroId: choice.macroId, mode: mode)),
              itemBuilder: (_) => [
                for (final (mode, icon, label) in _playModes)
                  PopupMenuItem(
                    height: 40,
                    value: mode,
                    child: _MenuRow(
                      checked: mode == choice.mode,
                      icon: icon,
                      label: label,
                    ),
                  ),
              ],
              child: _ComboBox(
                icon: modeIcon,
                label: modeLabel,
                enabled: !locked,
              ),
            ),
          ],
        ),
        if (playing)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              switch (choice.mode) {
                MacroPlayMode.once => '● выполняется',
                MacroPlayMode.loop => '● выполняется · круг ${loops + 1}',
                MacroPlayMode.pingPong =>
                  '● выполняется · круг ${loops + 1}, '
                      '${backward ? 'обратно' : 'туда'}',
              },
              style: TextStyle(
                color: colors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Поле выпадающего списка в стиле Windows.
class _ComboBox extends StatelessWidget {
  const _ComboBox({
    required this.label,
    this.icon,
    this.placeholder = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final bool placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          border: Border.all(color: AppColors.of(context).controlBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onSurface),
              const SizedBox(width: 6),
            ],
            Flexible(
              fit: icon == null ? FlexFit.tight : FlexFit.loose,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: placeholder ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Пункт выпадающего меню: отметка или значок, название и подпись справа.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    this.checked = false,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  final String label;
  final bool checked;
  final IconData? icon;
  final Color? iconColor;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: checked
              ? Icon(Icons.check, size: 18, color: scheme.primary)
              : null,
        ),
        const SizedBox(width: 6),
        if (icon != null) ...[
          Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              trailing!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Панель макросов внизу главного экрана: запуск, запись и остановка.
class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.controller,
    required this.onRecord,
    required this.onStart,
    required this.onManage,
  });

  final AppController controller;
  final VoidCallback onRecord;
  final VoidCallback onStart;
  final VoidCallback onManage;

  static String _inWindows(int n) =>
      n % 10 == 1 && n % 100 != 11 ? 'в $n окне' : 'в $n окнах';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final recorder = controller.macroRecorder;
    final player = controller.macroPlayer;

    final Widget leading;
    final String title;
    final String subtitle;
    final List<Widget> actions;
    if (recorder.waiting) {
      leading = Icon(Icons.keyboard_outlined, color: scheme.primary);
      title = 'Ждёт F8';
      subtitle = 'Перейдите в окно Roblox и нажмите F8';
      actions = [
        OutlinedButton(
          onPressed: controller.cancelRecording,
          child: const Text('Отмена'),
        ),
      ];
    } else if (recorder.recording) {
      leading = _Dot(color: colors.record);
      title = 'Идёт запись';
      subtitle = 'F8 в окне Roblox — закончить';
      actions = [
        OutlinedButton.icon(
          onPressed: controller.stopRecording,
          icon: const Icon(Icons.stop, size: 18),
          label: const Text('Закончить'),
        ),
      ];
    } else if (player.waiting) {
      leading = Icon(Icons.keyboard_outlined, color: scheme.primary);
      title = 'Ждёт F8';
      subtitle = 'Перейдите в окно Roblox и нажмите F8 — макросы запустятся';
      actions = [
        OutlinedButton(
          onPressed: controller.stopMacros,
          child: const Text('Отмена'),
        ),
      ];
    } else if (player.running) {
      final playing = controller.runningAccounts
          .where((a) => player.isPlaying(a.userId))
          .length;
      leading = _Dot(color: colors.success);
      title = 'Макросы выполняются';
      subtitle = '${_inWindows(playing)} · F8 — остановить';
      actions = [
        OutlinedButton.icon(
          onPressed: controller.stopMacros,
          icon: const Icon(Icons.stop, size: 18),
          label: const Text('Остановить'),
        ),
      ];
    } else {
      final running = controller.runningAccounts.length;
      final chosen = controller.accountsWithMacro.length;
      leading = Icon(Icons.keyboard_outlined, color: scheme.onSurfaceVariant);
      title = 'Макросы';
      subtitle = running == 0
          ? 'Запустите аккаунт, чтобы выбрать макрос'
          : chosen == 0
          ? 'Выберите макрос в карточке аккаунта'
          : 'Выбраны ${_inWindows(chosen)}';
      actions = [
        TextButton.icon(
          onPressed: running == 0 ? null : onRecord,
          icon: Icon(
            Icons.fiber_manual_record,
            size: 14,
            color: running == 0 ? null : colors.record,
          ),
          label: const Text('Записать'),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: chosen == 0 ? null : onStart,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Запустить'),
        ),
      ];
    }

    return Material(
      color: colors.bar,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Сохранённые макросы',
                  child: InkWell(
                    onTap: onManage,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 24,
                            child: Center(child: leading),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                                Text(
                                  subtitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Точка с ореолом: идёт запись или выполняются макросы.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), spreadRadius: 4),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.of(context).success,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
