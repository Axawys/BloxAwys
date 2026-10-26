<div align="center">

<img src="assets/icon/app_icon.png" alt="BloxAwys" width="128">

# BloxAwys

Запускает несколько окон Roblox одновременно, каждое под своим аккаунтом.

**Русский** · [English](README.en.md)

[![Скачать](https://img.shields.io/github/v/release/Axawys/BloxAwys?label=%D0%A1%D0%BA%D0%B0%D1%87%D0%B0%D1%82%D1%8C&style=for-the-badge&color=3B82F6)](https://github.com/Axawys/BloxAwys/releases/latest)

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

</div>

## Скриншоты

<div align="center">
<img src="docs/screenshots/multi.png" alt="Два окна Roblox под разными аккаунтами и BloxAwys" width="800">
<br><br>
<img src="docs/screenshots/main.png" alt="Главное окно BloxAwys" width="320">
</div>

## Возможности

- Можно держать открытыми несколько окон Roblox под разными аккаунтами. Новое окно не закрывает предыдущие.
- Аккаунты сохраняются в списке. Входить нужно один раз, потом Roblox запускается кнопкой ▶ без пароля.
- Можно отметить несколько аккаунтов и запустить их разом.
- Если вставить ссылку на игру или Place ID, окна откроются сразу в этой игре. Без ссылки откроется главный экран Roblox.
- Логин и пароль вводятся на roblox.com во встроенном окне, клиент их не видит и не хранит.
- Сессии хранятся только на вашем компьютере, в зашифрованном виде.
- Если Roblox сбросил вход, у аккаунта появится кнопка «Войти заново».
- Работает с Bloxstrap и Fishstrap: находит установленный через них Roblox и запускает его напрямую.

## Установка

1. Скачайте `setup.exe` со страницы [последнего релиза](https://github.com/Axawys/BloxAwys/releases/latest).
2. Запустите установщик. Если появится окно «Windows защитила ваш компьютер», нажмите «Подробнее», затем «Выполнить в любом случае». Windows показывает его, потому что у программы нет платной цифровой подписи.
3. Откройте BloxAwys, нажмите «Войти и запустить Roblox» и войдите в аккаунт.

Остальные аккаунты добавляются так же. После этого выбирайте аккаунты в списке и запускайте.

Пока открыты окна Roblox, BloxAwys должен быть запущен. Если его закрыть, следующее окно Roblox закроет предыдущие.

## Безопасность

Клиент обращается только к серверам Roblox, своих серверов у него нет. Сессии шифруются средствами Windows (DPAPI) и привязаны к вашей учётной записи, поэтому на другом компьютере или под другим пользователем их не расшифровать. Код открыт и лежит в этом репозитории. На странице каждого релиза есть отчёт VirusTotal и контрольная сумма установщика.

Сессия даёт полный доступ к аккаунту, так что не передавайте никому файлы из папки `%APPDATA%\com.axawys`.

## Частые вопросы

<details>
<summary>Окна Roblox всё равно закрывают друг друга</summary>

Скорее всего, Roblox был открыт до запуска BloxAwys, клиент в этом случае показывает предупреждение. Закройте все окна Roblox, перезапустите BloxAwys и запускайте аккаунты из него.
</details>

<details>
<summary>У аккаунта написано «Сессия истекла»</summary>

Так бывает, если нажать «Выйти» внутри Roblox, сменить пароль или завершить сеансы в настройках аккаунта. Нажмите «Войти заново» и войдите ещё раз.
</details>

<details>
<summary>«Roblox не установлен»</summary>

Установите Roblox с [roblox.com](https://www.roblox.com/download) и нажмите «Проверить». Подходит обычная установка, Bloxstrap и Fishstrap.
</details>

## Техническая информация

<details>
<summary>Как это работает</summary>

Вход идёт через встроенный WebView2 со страницей `roblox.com/login`. Для каждого входа создаётся временный профиль. После входа клиент забирает cookie `.ROBLOSECURITY` и удаляет профиль. Из аккаунта он при этом не выходит, иначе cookie стала бы недействительной.

Аккаунты хранятся через `flutter_secure_storage` (DPAPI) в `%APPDATA%\com.axawys\bloxawys\flutter_secure_storage.dat`.

Для запуска клиент обменивает cookie на одноразовый тикет (`auth.roblox.com/v1/authentication-ticket`) и запускает с ним `RobloxPlayerBeta.exe` напрямую. Протокол `roblox-player:` не используется, чтобы его не перехватил Bloxstrap. Если Roblox прислал в ответе обновлённую cookie, клиент её сохраняет.

Чтобы окна не закрывали друг друга, клиент при старте создаёт `ROBLOX_singletonMutex` и `ROBLOX_singletonEvent` и держит их, пока открыт (`lib/services/multi_instance.dart`).

При запуске нескольких аккаунтов между ними выдерживается пауза 2 секунды.

</details>

<details>
<summary>Сборка на Windows</summary>

1. Установить [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop).
2. Установить Visual Studio 2022 с нагрузкой «Разработка классических приложений на C++».
3. Установить NuGet CLI, он нужен плагину WebView: `winget install Microsoft.NuGet`, затем перезапустить терминал.
4. Включить режим разработчика Windows (Параметры → Система → Для разработчиков). Без него Flutter не может создавать симлинки для плагинов.
5. В папке проекта:
   ```
   flutter pub get
   flutter run -d windows
   ```
   Релизная сборка: `flutter build windows`, файлы появятся в `build\windows\x64\runner\Release\`.

Чтобы сборка запустилась на другом компьютере, рядом с `bloxawys.exe` должны лежать `msvcp140.dll`, `vcruntime140.dll` и `vcruntime140_1.dll`, либо там должен быть установлен Visual C++ Redistributable. WebView2 Runtime в Windows 10 и 11 обычно уже есть.

</details>

<details>
<summary>Проверка интерфейса на Linux</summary>

```
./run_linux.sh
```

Скрипт собирает демо-версию (`lib/main_demo.dart`) и открывает окно 520×760, как на Windows. В Hyprland окно открывается плавающим. В демо три тестовых аккаунта в памяти, а «запуск» только показывает индикатор. Вход и запуск Roblox на Linux не работают, потому что там нет WebView2 и Roblox. Тема собирается как для Windows и использует шрифт Segoe UI; если его нет, берётся системный.

`./run_linux.sh --real` запускает обычную версию вместо демо.

</details>

<details>
<summary>Структура проекта</summary>

```
lib/
├── main.dart                  точка входа
├── main_demo.dart             демо-режим для проверки интерфейса
├── app_controller.dart        состояние приложения: аккаунты, запуск
├── models/account.dart        сохранённый аккаунт
├── services/
│   ├── account_store.dart     зашифрованное хранилище
│   ├── roblox_api.dart        API Roblox: пользователь, аватары, тикет
│   ├── roblox_launcher.dart   поиск и запуск RobloxPlayerBeta.exe
│   └── multi_instance.dart    несколько окон Roblox
└── ui/
    ├── home_page.dart         главное окно
    └── login_page.dart        окно входа (WebView2)
```

</details>

## Лицензия

[GNU GPL v3](LICENSE). Код можно использовать, изменять и распространять, но изменённые версии тоже нужно публиковать с открытым кодом под GPLv3.

<sub>BloxAwys не связан с Roblox Corporation. Roblox является товарным знаком Roblox Corporation.</sub>
