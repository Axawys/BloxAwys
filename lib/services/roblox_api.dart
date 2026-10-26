import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cookie недействительна: нужно войти в аккаунт заново.
class RobloxAuthException implements Exception {
  const RobloxAuthException();

  @override
  String toString() => 'Сессия аккаунта истекла, войдите заново';
}

class RobloxApiException implements Exception {
  RobloxApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RobloxUser {
  RobloxUser({required this.id, required this.name, required this.displayName});
  final int id;
  final String name;
  final String displayName;
}

class AuthTicket {
  AuthTicket(this.ticket, this.rotatedCookie);
  final String ticket;

  /// Новое значение `.ROBLOSECURITY`, если Roblox обновил cookie в ответе.
  final String? rotatedCookie;
}

class RobloxApi {
  RobloxApi([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'BloxAwys/0.1';

  Map<String, String> _headers(String cookie, {String? csrf}) => {
    'Cookie': '.ROBLOSECURITY=$cookie',
    'User-Agent': _userAgent,
    'Referer': 'https://www.roblox.com/',
    'Origin': 'https://www.roblox.com',
    'Content-Type': 'application/json',
    'X-CSRF-TOKEN': ?csrf,
  };

  Future<RobloxUser> getAuthenticatedUser(String cookie) async {
    final res = await _client.get(
      Uri.parse('https://users.roblox.com/v1/users/authenticated'),
      headers: _headers(cookie),
    );
    if (res.statusCode == 401) throw const RobloxAuthException();
    if (res.statusCode != 200) {
      throw RobloxApiException(
        'Не удалось получить данные аккаунта (HTTP ${res.statusCode})',
      );
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return RobloxUser(
      id: json['id'] as int,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
    );
  }

  /// Ссылки на аватары (headshot) для списка пользователей.
  Future<Map<int, String>> getHeadshots(List<int> userIds) async {
    if (userIds.isEmpty) return {};
    final uri = Uri.https(
      'thumbnails.roblox.com',
      '/v1/users/avatar-headshot',
      {
        'userIds': userIds.join(','),
        'size': '150x150',
        'format': 'Png',
        'isCircular': 'false',
      },
    );
    final res = await _client.get(uri, headers: {'User-Agent': _userAgent});
    if (res.statusCode != 200) return {};
    final data = (jsonDecode(res.body) as Map<String, dynamic>)['data'] as List;
    return {
      for (final item in data.cast<Map<String, dynamic>>())
        if (item['state'] == 'Completed' && item['imageUrl'] != null)
          item['targetId'] as int: item['imageUrl'] as String,
    };
  }

  /// Одноразовый тикет, которым RobloxPlayerBeta.exe авторизуется при запуске.
  ///
  /// Первый запрос без CSRF-токена Roblox отклоняет с 403 и присылает токен
  /// в заголовке `x-csrf-token`, после чего запрос повторяется с ним.
  Future<AuthTicket> getAuthTicket(String cookie) async {
    final uri = Uri.parse('https://auth.roblox.com/v1/authentication-ticket');
    String? csrf;
    for (var attempt = 0; attempt < 2; attempt++) {
      final res = await _client.post(
        uri,
        headers: _headers(cookie, csrf: csrf),
        body: '{}',
      );
      if (res.statusCode == 401) throw const RobloxAuthException();
      if (res.statusCode == 403 && res.headers['x-csrf-token'] != null) {
        csrf = res.headers['x-csrf-token'];
        continue;
      }
      final ticket = res.headers['rbx-authentication-ticket'];
      if (res.statusCode == 200 && ticket != null && ticket.isNotEmpty) {
        return AuthTicket(ticket, _rotatedCookie(res, cookie));
      }
      throw RobloxApiException(
        'Не удалось получить тикет запуска (HTTP ${res.statusCode})',
      );
    }
    throw RobloxApiException('Roblox не принял CSRF-токен');
  }

  String? _rotatedCookie(http.Response res, String current) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie == null) return null;
    final match = RegExp(r'\.ROBLOSECURITY=([^;,\s]+)').firstMatch(setCookie);
    final value = match?.group(1);
    if (value == null || value.isEmpty || value == current) return null;
    return value;
  }
}
