/// Сохранённый аккаунт Roblox.
///
/// [cookie] — значение `.ROBLOSECURITY`. Оно даёт полный доступ к аккаунту,
/// поэтому хранится только в зашифрованном хранилище (см. AccountStore).
class Account {
  Account({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.cookie,
    this.avatarUrl,
    this.needsRelogin = false,
  });

  final int userId;
  final String username;
  final String displayName;
  final String cookie;
  final String? avatarUrl;

  /// Roblox отклонил cookie (выход из аккаунта, сброс сессии и т.п.).
  final bool needsRelogin;

  Account copyWith({
    String? username,
    String? displayName,
    String? cookie,
    String? avatarUrl,
    bool? needsRelogin,
  }) {
    return Account(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      cookie: cookie ?? this.cookie,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      needsRelogin: needsRelogin ?? this.needsRelogin,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'displayName': displayName,
    'cookie': cookie,
    'avatarUrl': avatarUrl,
    'needsRelogin': needsRelogin,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    userId: json['userId'] as int,
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    cookie: json['cookie'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    needsRelogin: json['needsRelogin'] as bool? ?? false,
  );
}
