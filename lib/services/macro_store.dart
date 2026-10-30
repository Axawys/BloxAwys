import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/macro.dart';

/// Хранит макросы в macros.json рядом с настройками.
class MacroStore {
  Future<File> _file() async => File(
    p.join((await getApplicationSupportDirectory()).path, 'macros.json'),
  );

  Future<List<Macro>> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return [];
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return [for (final m in list) Macro.fromJson(m as Map<String, dynamic>)];
    } catch (_) {
      // Повреждённый файл не должен мешать запуску клиента.
      return [];
    }
  }

  Future<void> save(List<Macro> macros) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([for (final m in macros) m.toJson()]));
  }
}
