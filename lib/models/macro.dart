enum MacroEventType { keyDown, keyUp, move, buttonDown, buttonUp, wheel }

enum MouseButton { left, right, middle }

/// Одно действие макроса.
///
/// Клавиши хранятся скан-кодами. Движение мыши — относительным смещением,
/// как его видит игра: так вращается камера. У нажатий кнопок мыши есть
/// точка внутри окна в долях его размера, чтобы клик попал туда же
/// в окне другого размера.
class MacroEvent {
  const MacroEvent({
    required this.t,
    required this.type,
    this.scanCode = 0,
    this.extended = false,
    this.dx = 0,
    this.dy = 0,
    this.button = MouseButton.left,
    this.x,
    this.y,
    this.wheel = 0,
  });

  /// Миллисекунды от начала макроса.
  final int t;
  final MacroEventType type;
  final int scanCode;
  final bool extended;
  final int dx;
  final int dy;
  final MouseButton button;
  final double? x;
  final double? y;
  final int wheel;

  bool get isKey =>
      type == MacroEventType.keyDown || type == MacroEventType.keyUp;

  bool get isButton =>
      type == MacroEventType.buttonDown || type == MacroEventType.buttonUp;

  Map<String, dynamic> toJson() => {
    't': t,
    'type': type.name,
    if (isKey) 'scan': scanCode,
    if (isKey && extended) 'ext': true,
    if (type == MacroEventType.move) ...{'dx': dx, 'dy': dy},
    if (isButton) 'button': button.name,
    if (isButton && x != null) ...{'x': x, 'y': y},
    if (type == MacroEventType.wheel) 'wheel': wheel,
  };

  factory MacroEvent.fromJson(Map<String, dynamic> json) => MacroEvent(
    t: json['t'] as int,
    type: MacroEventType.values.byName(json['type'] as String),
    scanCode: json['scan'] as int? ?? 0,
    extended: json['ext'] as bool? ?? false,
    dx: json['dx'] as int? ?? 0,
    dy: json['dy'] as int? ?? 0,
    button: MouseButton.values.asNameMap()[json['button']] ?? MouseButton.left,
    x: (json['x'] as num?)?.toDouble(),
    y: (json['y'] as num?)?.toDouble(),
    wheel: json['wheel'] as int? ?? 0,
  );
}

class Macro {
  const Macro({
    required this.id,
    required this.name,
    required this.events,
    required this.durationMs,
  });

  final String id;
  final String name;
  final List<MacroEvent> events;

  /// Длина одного круга, включая паузу после последнего действия.
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  Macro copyWith({String? name}) => Macro(
    id: id,
    name: name ?? this.name,
    events: events,
    durationMs: durationMs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationMs': durationMs,
    'events': [for (final e in events) e.toJson()],
  };

  factory Macro.fromJson(Map<String, dynamic> json) => Macro(
    id: json['id'] as String,
    name: json['name'] as String,
    durationMs: json['durationMs'] as int,
    events: [
      for (final e in json['events'] as List<dynamic>)
        MacroEvent.fromJson(e as Map<String, dynamic>),
    ],
  );
}
