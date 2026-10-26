import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

class RobloxNotFoundException implements Exception {
  @override
  String toString() =>
      'Roblox не найден. Установите его с roblox.com и перезапустите клиент.';
}

/// Ищет установленный RobloxPlayerBeta.exe и запускает его с тикетом.
class RobloxLauncher {
  static const _exeName = 'RobloxPlayerBeta.exe';

  String? _exePath;
  String? get exePath => _exePath ??= _findPlayerExe();

  void refresh() => _exePath = _findPlayerExe();

  /// Exe запускается напрямую, а не через протокол `roblox-player:`, потому что
  /// протокол может перехватить Bloxstrap. Самая свежая версия выбирается
  /// по дате изменения файла.
  static String? _findPlayerExe() {
    final env = Platform.environment;
    final localAppData = env['LOCALAPPDATA'];
    final roots = <String>[
      if (localAppData != null) ...[
        p.join(localAppData, 'Roblox', 'Versions'),
        p.join(localAppData, 'Bloxstrap', 'Versions'),
        p.join(localAppData, 'Fishstrap', 'Versions'),
      ],
      for (final base in [env['ProgramFiles(x86)'], env['ProgramFiles']])
        if (base != null) p.join(base, 'Roblox', 'Versions'),
    ];

    File? best;
    DateTime? bestTime;
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync().whereType<Directory>()) {
        final exe = File(p.join(entry.path, _exeName));
        if (!exe.existsSync()) continue;
        final modified = exe.lastModifiedSync();
        if (bestTime == null || modified.isAfter(bestTime)) {
          best = exe;
          bestTime = modified;
        }
      }
    }
    return best?.path;
  }

  /// Запускает Roblox. Без [placeId] открывается главный экран приложения,
  /// с ним — сразу эта игра.
  Future<void> launch({required String ticket, int? placeId}) async {
    if (exePath == null || !File(exePath!).existsSync()) refresh();
    final exe = exePath ?? (throw RobloxNotFoundException());

    await Process.start(
      exe,
      [buildLaunchUri(ticket: ticket, placeId: placeId)],
      workingDirectory: p.dirname(exe),
      mode: ProcessStartMode.detached,
    );
  }

  /// Та же строка, которую сайт Roblox передаёт через протокол `roblox-player:`.
  static String buildLaunchUri({required String ticket, int? placeId}) {
    final launchTime = DateTime.now().millisecondsSinceEpoch;
    final trackerId = _browserTrackerId();
    final parts = <String>[
      'roblox-player:1',
      'launchmode:${placeId == null ? 'app' : 'play'}',
      'gameinfo:$ticket',
      'launchtime:$launchTime',
      if (placeId != null)
        'placelauncherurl:${Uri.encodeComponent('https://assetgame.roblox.com/game/PlaceLauncher.ashx'
        '?request=RequestGame&browserTrackerId=$trackerId'
        '&placeId=$placeId&isPlayTogetherGame=false')}',
      'browsertrackerid:$trackerId',
      'robloxLocale:en_us',
      'gameLocale:en_us',
      'channel:',
    ];
    return parts.join('+');
  }

  static String _browserTrackerId() {
    final r = Random();
    return '${100000 + r.nextInt(900000)}${100000 + r.nextInt(900000)}';
  }
}

/// Достаёт ID плейса из числа или ссылки вида roblox.com/games/123456/...
int? parsePlaceId(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final direct = int.tryParse(text);
  if (direct != null) return direct;
  final match =
      RegExp(r'/games/(\d+)').firstMatch(text) ??
      RegExp(r'placeId=(\d+)').firstMatch(text);
  return match == null ? null : int.parse(match.group(1)!);
}
