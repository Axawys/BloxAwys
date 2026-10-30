/// Что нажимать, чтобы Roblox не отключил за бездействие.
enum AntiAfkAction {
  /// Стрелки влево-вправо: камера поворачивается и возвращается.
  camera,

  /// A и D: персонаж делает шаг в сторону и обратно.
  strafe,

  /// Пробел: персонаж подпрыгивает.
  jump,
}

class AntiAfkSettings {
  const AntiAfkSettings({
    this.enabled = false,
    this.action = AntiAfkAction.camera,
    this.intervalMinutes = 10,
    this.respectUserActivity = true,
  });

  /// Допустимые интервалы. Roblox отключает через 20 минут бездействия.
  static const intervals = [5, 10, 15];

  final bool enabled;
  final AntiAfkAction action;
  final int intervalMinutes;

  /// Откладывать нажатия, пока пользователь пользуется компьютером.
  final bool respectUserActivity;

  AntiAfkSettings copyWith({
    bool? enabled,
    AntiAfkAction? action,
    int? intervalMinutes,
    bool? respectUserActivity,
  }) {
    return AntiAfkSettings(
      enabled: enabled ?? this.enabled,
      action: action ?? this.action,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      respectUserActivity: respectUserActivity ?? this.respectUserActivity,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'action': action.name,
    'intervalMinutes': intervalMinutes,
    'respectUserActivity': respectUserActivity,
  };

  factory AntiAfkSettings.fromJson(Map<String, dynamic> json) {
    final interval = json['intervalMinutes'] as int?;
    return AntiAfkSettings(
      enabled: json['enabled'] as bool? ?? false,
      action:
          AntiAfkAction.values.asNameMap()[json['action']] ??
          AntiAfkAction.camera,
      intervalMinutes: intervals.contains(interval) ? interval! : 10,
      respectUserActivity: json['respectUserActivity'] as bool? ?? true,
    );
  }
}

class MacroSettings {
  const MacroSettings({
    this.enabled = false,
    this.stopOnUserInput = true,
    this.recordMouseMovement = true,
  });

  /// Модуль макросов включён: в шапке появляется кнопка «Макросы».
  final bool enabled;

  /// Останавливать макросы, если пользователь взялся за мышь или клавиатуру.
  final bool stopOnUserInput;

  /// Записывать движения мыши (поворот камеры), а не только клики.
  final bool recordMouseMovement;

  MacroSettings copyWith({
    bool? enabled,
    bool? stopOnUserInput,
    bool? recordMouseMovement,
  }) {
    return MacroSettings(
      enabled: enabled ?? this.enabled,
      stopOnUserInput: stopOnUserInput ?? this.stopOnUserInput,
      recordMouseMovement: recordMouseMovement ?? this.recordMouseMovement,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'stopOnUserInput': stopOnUserInput,
    'recordMouseMovement': recordMouseMovement,
  };

  factory MacroSettings.fromJson(Map<String, dynamic> json) => MacroSettings(
    enabled: json['enabled'] as bool? ?? false,
    stopOnUserInput: json['stopOnUserInput'] as bool? ?? true,
    recordMouseMovement: json['recordMouseMovement'] as bool? ?? true,
  );
}

/// Настройки клиента. Сюда же лягут настройки будущих модулей.
class AppSettings {
  const AppSettings({
    this.antiAfk = const AntiAfkSettings(),
    this.macros = const MacroSettings(),
  });

  final AntiAfkSettings antiAfk;
  final MacroSettings macros;

  AppSettings copyWith({AntiAfkSettings? antiAfk, MacroSettings? macros}) =>
      AppSettings(
        antiAfk: antiAfk ?? this.antiAfk,
        macros: macros ?? this.macros,
      );

  Map<String, dynamic> toJson() => {
    'antiAfk': antiAfk.toJson(),
    'macros': macros.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    antiAfk: json['antiAfk'] is Map<String, dynamic>
        ? AntiAfkSettings.fromJson(json['antiAfk'] as Map<String, dynamic>)
        : const AntiAfkSettings(),
    macros: json['macros'] is Map<String, dynamic>
        ? MacroSettings.fromJson(json['macros'] as Map<String, dynamic>)
        : const MacroSettings(),
  );
}
