import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/settings.dart';

/// Хранит настройки в settings.json рядом с данными аккаунтов
/// (на Windows — `%APPDATA%\com.axawys\bloxawys`). Секретов в настройках нет,
/// поэтому они не шифруются.
class SettingsStore {
  Future<File> _file() async => File(
    p.join((await getApplicationSupportDirectory()).path, 'settings.json'),
  );

  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return const AppSettings();
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic>
          ? AppSettings.fromJson(json)
          : const AppSettings();
    } catch (_) {
      // Повреждённый файл не должен мешать запуску: берём настройки
      // по умолчанию, при следующем сохранении файл перезапишется.
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
