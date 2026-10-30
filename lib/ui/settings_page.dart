import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  static Future<void> open(BuildContext context, AppController controller) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsPage(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _AntiAfkSection(controller: controller),
            const Divider(height: 32),
            _MacrosSection(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _AntiAfkSection extends StatelessWidget {
  const _AntiAfkSection({required this.controller});

  final AppController controller;

  AntiAfkSettings get _s => controller.settings.antiAfk;

  void _change(AntiAfkSettings value) =>
      controller.updateSettings(controller.settings.copyWith(antiAfk: value));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supported = controller.antiAfk.supported;
    final enabled = _s.enabled && supported;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header('Анти-AFK'),
        SwitchListTile(
          title: const Text('Не отключать за бездействие'),
          subtitle: Text(
            supported
                ? 'Roblox отключает игрока через 20 минут без действий. '
                      'Анти-AFK время от времени нажимает клавиши в окнах Roblox.'
                : 'Работает только в Windows.',
          ),
          value: enabled,
          onChanged: supported ? (v) => _change(_s.copyWith(enabled: v)) : null,
        ),
        if (enabled) ...[
          header('Что нажимать'),
          RadioGroup<AntiAfkAction>(
            groupValue: _s.action,
            onChanged: (v) {
              if (v != null) _change(_s.copyWith(action: v));
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: AntiAfkAction.camera,
                  title: Text('Камера'),
                  subtitle: Text(
                    'Стрелки влево и вправо. Персонаж стоит на месте.',
                  ),
                ),
                RadioListTile(
                  value: AntiAfkAction.strafe,
                  title: Text('Шаг в сторону'),
                  subtitle: Text(
                    'A и D. Помогает в играх, которые проверяют, двигается ли '
                    'персонаж, но может сдвинуть его с места.',
                  ),
                ),
                RadioListTile(
                  value: AntiAfkAction.jump,
                  title: Text('Прыжок'),
                  subtitle: Text(
                    'Пробел. Может поднять персонажа с сиденья или прервать '
                    'действие.',
                  ),
                ),
              ],
            ),
          ),
          header('Как часто'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<int>(
              segments: [
                for (final m in AntiAfkSettings.intervals)
                  ButtonSegment(value: m, label: Text('$m мин')),
              ],
              selected: {_s.intervalMinutes},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  _change(_s.copyWith(intervalMinutes: v.first)),
            ),
          ),
          SwitchListTile(
            title: const Text('Не мешать, когда я за компьютером'),
            subtitle: const Text(
              'Если вы пользовались мышью или клавиатурой последние 30 секунд, '
              'нажатие откладывается.',
            ),
            value: _s.respectUserActivity,
            onChanged: (v) => _change(_s.copyWith(respectUserActivity: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Windows передаёт нажатия только активному окну, поэтому каждое '
              'окно Roblox на мгновение становится активным, а потом фокус '
              'возвращается обратно. Свёрнутые окна разворачиваются на время '
              'нажатия и сворачиваются снова.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
        ],
      ],
    );
  }
}

class _MacrosSection extends StatelessWidget {
  const _MacrosSection({required this.controller});

  final AppController controller;

  MacroSettings get _s => controller.settings.macros;

  void _change(MacroSettings value) =>
      controller.updateSettings(controller.settings.copyWith(macros: value));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supported = controller.antiAfk.supported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Макросы',
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
        ),
        SwitchListTile(
          title: const Text('Включить макросы'),
          subtitle: Text(
            supported
                ? 'Запись клавиатуры и мыши в окне Roblox и повтор по кругу. '
                      'В шапке появится кнопка «Макросы».'
                : 'Работает только в Windows.',
          ),
          value: _s.enabled,
          onChanged: (v) => _change(_s.copyWith(enabled: v)),
        ),
        if (_s.enabled) ...[
          SwitchListTile(
            title: const Text('Записывать движения мыши'),
            subtitle: const Text(
              'Нужно для поворота камеры. Без этого записываются только '
              'клавиши, клики и колесо.',
            ),
            value: _s.recordMouseMovement,
            onChanged: (v) => _change(_s.copyWith(recordMouseMovement: v)),
          ),
          SwitchListTile(
            title: const Text('Останавливать, если я взялся за мышь'),
            subtitle: const Text(
              'Макросы остановятся, как только вы нажмёте клавишу, кнопку '
              'мыши или сдвинете её. F8 останавливает всегда.',
            ),
            value: _s.stopOnUserInput,
            onChanged: (v) => _change(_s.copyWith(stopOnUserInput: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Многие игры запрещают макросы своими правилами и могут '
              'заблокировать за них аккаунт. Это решает игра, а не BloxAwys.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
        ],
      ],
    );
  }
}
