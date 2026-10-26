import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/account.dart';

/// Хранит список аккаунтов. На Windows flutter_secure_storage шифрует данные
/// через DPAPI, так что расшифровать их может только текущий пользователь
/// Windows.
class AccountStore {
  static const _key = 'accounts';
  final _storage = const FlutterSecureStorage();

  Future<List<Account>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Account> accounts) async {
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }
}
