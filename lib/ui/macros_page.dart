import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/account.dart';
import '../models/macro.dart';
import '../services/macro_recorder.dart';

class MacrosPage extends StatefulWidget {
  const MacrosPage({super.key, required this.controller});

  final AppController controller;

  static Future<void> open(BuildContext context, AppController controller) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MacrosPage(controller: controller)),
    );
  }

  @override
  State<MacrosPage> createState() => _MacrosPageState();
}

class _MacrosPageState extends State<MacrosPage> {
  AppController get _c => widget.controller;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _record() async {
    final running = _c.runningAccounts;
    if (running.isEmpty) {
      _snack('Сначала запустите аккаунт на главном экране');
      return;
    }
    final account = running.length == 1
        ? running.single
        : await showDialog<Account>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('В каком окне записывать?'),
              children: [
                for (final a in running)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, a),
                    child: Text(a.displayName),
                  ),
              ],
            ),
          );
    if (account == null || !mounted) return;

    final start = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Запись в окне ${account.displayName}'),
        content: const Text(
          'Окно Roblox станет активным, и BloxAwys начнёт записывать '
          'клавиатуру и мышь в нём. Чтобы закончить, нажмите F8.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Начать запись'),
          ),
        ],
      ),
    );
    if (start != true || !mounted) return;

    final Macro? macro;
    try {
      macro = await _c.recordMacro(account);
    } on MacroException catch (e) {
      _snack('$e');
      return;
    }
    if (!mounted) return;
    if (macro == null) {
      _snack('Ничего не записано');
      return;
    }
    final name = await _askName(
      title: 'Сохранить макрос',
      initial: 'Макрос ${_c.macros.length + 1}',
      details:
          '${_formatDuration(macro.durationMs)} · ${_actions(macro.events.length)}',
    );
    if (name == null) return;
    await _c.addMacro(macro, name);
    // Только что записанный макрос сразу выбирается для этого окна.
    if (_c.macroChoiceFor(account).macroId == null) {
      _c.setMacroChoice(account, MacroChoice(macroId: macro.id));
    }
  }

  Future<String?> _askName({
    required String title,
    required String initial,
    String? details,
  }) {
    final field = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details != null) ...[Text(details), const SizedBox(height: 16)],
            TextField(
              controller: field,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ).then((v) => v == null || v.isEmpty ? null : v);
  }

  Future<void> _rename(Macro macro) async {
    final name = await _askName(title: 'Переименовать', initial: macro.name);
    if (name != null) await _c.renameMacro(macro, name);
  }

  Future<void> _delete(Macro macro) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить макрос?'),
        content: Text('«${macro.name}» удалится без возможности вернуть.'),
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
    if (ok == true) await _c.deleteMacro(macro);
  }

  void _startOrStop() {
    if (_c.macroPlayer.running) {
      _c.stopMacros();
      return;
    }
    final chosen = _c.runningAccounts.any(
      (a) => _c.macros.any((m) => m.id == _c.macroChoiceFor(a).macroId),
    );
    if (!chosen) {
      _snack('Выберите макрос хотя бы для одного окна');
      return;
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Макросы')),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final player = _c.macroPlayer;
          final running = _c.runningAccounts;

          Widget header(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (_c.macroRecorder.recording)
                Card(
                  color: scheme.errorContainer,
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.fiber_manual_record,
                      color: scheme.onErrorContainer,
                    ),
                    title: Text(
                      'Идёт запись. Нажмите F8, чтобы закончить.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    trailing: TextButton(
                      onPressed: _c.stopRecording,
                      child: const Text('Закончить'),
                    ),
                  ),
                ),
              header('Запуск в окнах'),
              if (running.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Запустите аккаунты на главном экране, и здесь появятся '
                    'их окна.',
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              else ...[
                for (final account in running)
                  _WindowRow(
                    account: account,
                    macros: _c.macros,
                    choice: _c.macroChoiceFor(account),
                    playing: player.isPlaying(account.userId),
                    loops: player.loopsOf(account.userId),
                    locked: player.running,
                    onChanged: (choice) => _c.setMacroChoice(account, choice),
                  ),
                const SizedBox(height: 8),
                player.running
                    ? FilledButton.tonalIcon(
                        onPressed: _startOrStop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Остановить (F8)'),
                      )
                    : FilledButton.icon(
                        onPressed: _c.macroRecorder.recording
                            ? null
                            : _startOrStop,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Запустить'),
                      ),
                if (!player.running && player.stopReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      player.stopReason!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
              header('Сохранённые макросы'),
              if (_c.macros.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Пока нет макросов. Запишите первый.',
                    style: TextStyle(color: scheme.outline),
                  ),
                ),
              for (final macro in _c.macros)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.keyboard_alt_outlined),
                    title: Text(macro.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${_formatDuration(macro.durationMs)} · '
                      '${_actions(macro.events.length)}',
                    ),
                    trailing: PopupMenuButton<VoidCallback>(
                      enabled: !player.running,
                      onSelected: (action) => action(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: () => _rename(macro),
                          child: const Text('Переименовать'),
                        ),
                        PopupMenuItem(
                          value: () => _delete(macro),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: player.running || _c.macroRecorder.recording
                    ? null
                    : _record,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Записать макрос'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                child: Text(
                  'F8 заканчивает запись и останавливает все макросы. '
                  'Windows передаёт ввод только активному окну, поэтому при '
                  'нескольких окнах макросы выполняются по очереди с '
                  'переключением между окнами, а пользоваться компьютером '
                  'в это время нельзя.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.account,
    required this.macros,
    required this.choice,
    required this.playing,
    required this.loops,
    required this.locked,
    required this.onChanged,
  });

  final Account account;
  final List<Macro> macros;
  final MacroChoice choice;
  final bool playing;
  final int loops;

  /// Макросы запущены: выбор менять нельзя.
  final bool locked;
  final ValueChanged<MacroChoice> onChanged;

  static const _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final selected = macros.any((m) => m.id == choice.macroId)
        ? choice.macroId
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (playing)
                  Text(
                    choice.loop
                        ? 'выполняется · круг ${loops + 1}'
                        : 'выполняется',
                    style: const TextStyle(color: _green, fontSize: 12),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: selected,
                    underline: const SizedBox.shrink(),
                    onChanged: locked
                        ? null
                        : (id) => onChanged(
                            MacroChoice(macroId: id, loop: choice.loop),
                          ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Без макроса'),
                      ),
                      for (final m in macros)
                        DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Повтор'),
                  selected: choice.loop,
                  onSelected: locked
                      ? null
                      : (v) => onChanged(
                          MacroChoice(macroId: choice.macroId, loop: v),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int ms) {
  final seconds = ms / 1000;
  if (seconds < 60) {
    return '${seconds.toStringAsFixed(1).replaceAll('.', ',')} с';
  }
  final whole = seconds.round();
  return '${whole ~/ 60} мин ${whole % 60} с';
}

String _actions(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'действие'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'действия'
      : 'действий';
  return '$n $word';
}
