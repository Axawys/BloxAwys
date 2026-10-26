import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Окно входа в Roblox. Возвращает значение cookie `.ROBLOSECURITY`
/// или null, если пользователь закрыл окно.
///
/// Каждый вход идёт в отдельном временном профиле WebView2, поэтому второй
/// вход не подхватывает первый аккаунт. После входа профиль удаляется.
/// Из аккаунта при этом не выходим: выход сделал бы сохранённую cookie
/// недействительной.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static Future<String?> open(BuildContext context) {
    return Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static final _robloxUrl = WebUri('https://www.roblox.com');

  Directory? _profileDir;
  WebViewEnvironment? _env;
  Timer? _poll;
  String? _error;
  bool _done = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _createEnvironment();
  }

  Future<void> _createEnvironment() async {
    try {
      final version = await WebViewEnvironment.getAvailableVersion();
      if (version == null) {
        setState(
          () => _error = 'Не найден Microsoft Edge WebView2 Runtime. Установите его с сайта Microsoft.',
        );
        return;
      }
      final dir = await Directory.systemTemp.createTemp('bloxawys_login_');
      final env = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: dir.path),
      );
      if (!mounted) {
        await env.dispose();
        _deleteProfile(dir);
        return;
      }
      setState(() {
        _profileDir = dir;
        _env = env;
      });
      // Запасная проверка на случай, если после входа не сработает onLoadStop.
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _checkCookie());
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось открыть окно входа: $e');
    }
  }

  Future<void> _checkCookie() async {
    final env = _env;
    if (env == null || _done) return;
    try {
      final cookie = await CookieManager.instance(webViewEnvironment: env)
          .getCookie(url: _robloxUrl, name: '.ROBLOSECURITY');
      final value = cookie?.value?.toString();
      if (value != null && value.isNotEmpty && !_done && mounted) {
        _done = true;
        Navigator.of(context).pop(value);
      }
    } catch (_) {
      // Окружение ещё не готово — проверим при следующей загрузке.
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    final env = _env;
    final dir = _profileDir;
    if (env != null) {
      env.dispose().whenComplete(() {
        if (dir != null) _deleteProfile(dir);
      });
    }
    super.dispose();
  }

  /// Процессы WebView2 держат файлы профиля ещё какое-то время после
  /// закрытия, поэтому удаляем с повторами.
  static Future<void> _deleteProfile(Directory dir) async {
    for (var i = 0; i < 10; i++) {
      try {
        if (dir.existsSync()) await dir.delete(recursive: true);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в Roblox'),
        bottom: _progress > 0 && _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress, minHeight: 2),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_env == null) return const Center(child: CircularProgressIndicator());

    return InAppWebView(
      webViewEnvironment: _env,
      initialUrlRequest: URLRequest(
        url: WebUri('https://www.roblox.com/login'),
      ),
      onLoadStop: (_, _) => _checkCookie(),
      onUpdateVisitedHistory: (_, _, _) => _checkCookie(),
      onProgressChanged: (_, progress) {
        if (mounted) setState(() => _progress = progress / 100);
      },
    );
  }
}
