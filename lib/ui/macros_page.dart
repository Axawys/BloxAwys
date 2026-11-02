import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/account.dart';
import '../models/macro.dart';
import '../services/macro_recorder.dart';
import 'theme.dart';

/// Сохранённые макросы: запись, переименование и удаление. Какой макрос
/// выполнять в каком окне, выбирается на главном экране.
class MacrosPage extends StatelessWidget {
  const MacrosPage({super.key, required this.controller});

  final AppController controller;

  static Future<void> open(BuildContext context, AppController controller) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MacrosPage(controller: controller)),
    );
  }

  Future<void> _rename(BuildContext context, Macro macro) async {
    final name = await _askName(
      context,
      title: 'Переименовать',
      initial: macro.name,
    );
    if (name != null) await controller.renameMacro(macro, name);
  }

  Future<void> _delete(BuildContext context, Macro macro) async {
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
    if (ok == true) await controller.deleteMacro(macro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Макросы')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final colors = AppColors.of(context);
          final player = controller.macroPlayer;
          final recorder = controller.macroRecorder;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              if (recorder.active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecordingCard(controller: controller),
                ),
              if (controller.macros.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(
                    'Пока нет макросов. Запустите аккаунт и запишите первый.',
                    style: TextStyle(color: scheme.outline),
                  ),
                ),
              for (final macro in controller.macros)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.keyboard_outlined,
                          size: 20,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(macro.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${formatMacroDuration(macro.durationMs)} · '
                        '${formatActionCount(macro.events.length)}',
                      ),
                      trailing: PopupMenuButton<VoidCallback>(
                        enabled: !player.active,
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (action) => action(),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: () => _rename(context, macro),
                            child: const Text('Переименовать'),
                          ),
                          PopupMenuItem(
                            value: () => _delete(context, macro),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: player.active || recorder.active
                    ? null
                    : () => recordAndSaveMacro(context, controller),
                icon: Icon(
                  Icons.fiber_manual_record,
                  size: 14,
                  color: colors.record,
                ),
                label: const Text('Записать макрос'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                child: Text(
                  'Запись начинается и заканчивается по F8 в окне Roblox. '
                  'Макрос для окна выбирается в карточке аккаунта на главном '
                  'экране. После кнопки «Запустить» макросы стартуют по F8 '
                  'в окне Roblox, и F8 же их останавливает. В режиме «Туда-обратно» каждый второй круг идёт '
                  'зеркально: W и S, A и D, стрелки меняются местами, мышь '
                  'поворачивает камеру обратно, и персонаж возвращается '
                  'к началу. Windows передаёт ввод только активному окну, '
                  'поэтому при нескольких окнах макросы выполняются по '
                  'очереди с переключением между окнами, а пользоваться '
                  'компьютером в это время нельзя.',
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

/// Карточка ожидания F8 или идущей записи.
class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waiting = controller.macroRecorder.waiting;
    final background = waiting
        ? scheme.primaryContainer
        : scheme.errorContainer;
    final foreground = waiting
        ? scheme.onPrimaryContainer
        : scheme.onErrorContainer;
    return Card(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(
          waiting ? Icons.keyboard_outlined : Icons.fiber_manual_record,
          color: foreground,
        ),
        title: Text(
          waiting
              ? 'Перейдите в окно Roblox и нажмите F8 — начнётся запись.'
              : 'Идёт запись. Нажмите F8, чтобы закончить.',
          style: TextStyle(color: foreground),
        ),
        trailing: TextButton(
          style: TextButton.styleFrom(foregroundColor: foreground),
          onPressed: waiting
              ? controller.cancelRecording
              : controller.stopRecording,
          child: Text(waiting ? 'Отмена' : 'Закончить'),
        ),
      ),
    );
  }
}

/// Записывает макрос по F8 и предлагает сохранить его. Только что записанный
/// макрос сразу выбирается для окна, где его записали, если там ещё ничего
/// не выбрано.
Future<void> recordAndSaveMacro(
  BuildContext context,
  AppController controller,
) async {
  void snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final ({Macro macro, Account? account})? recorded;
  try {
    recorded = await controller.recordMacro();
  } on MacroException catch (e) {
    snack('$e');
    return;
  }
  if (!context.mounted) return;
  if (recorded == null) {
    snack('Макрос не записан');
    return;
  }
  final (:macro, :account) = recorded;
  final name = await _askName(
    context,
    title: 'Сохранить макрос',
    initial: 'Макрос ${controller.macros.length + 1}',
    details:
        '${formatMacroDuration(macro.durationMs)} · '
        '${formatActionCount(macro.events.length)}',
  );
  if (name == null) return;
  await controller.addMacro(macro, name);
  if (account != null && controller.macroChoiceFor(account).macroId == null) {
    controller.setMacroChoice(account, MacroChoice(macroId: macro.id));
  }
}

Future<String?> _askName(
  BuildContext context, {
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
            decoration: const InputDecoration(labelText: 'Название'),
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

String formatMacroDuration(int ms) {
  final seconds = ms / 1000;
  if (seconds < 60) {
    return '${seconds.toStringAsFixed(1).replaceAll('.', ',')} с';
  }
  final whole = seconds.round();
  return '${whole ~/ 60} мин ${whole % 60} с';
}

String formatActionCount(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'действие'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'действия'
      : 'действий';
  return '$n $word';
}
