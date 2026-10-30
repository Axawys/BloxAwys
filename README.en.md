<div align="center">

<img src="assets/icon/app_icon.png" alt="BloxAwys" width="128">

# BloxAwys

Runs several Roblox windows at once, each signed in to its own account.

[Русский](README.md) · **English**

[![Download](https://img.shields.io/github/v/release/Axawys/BloxAwys?label=Download&style=for-the-badge&color=3B82F6)](https://github.com/Axawys/BloxAwys/releases/latest/download/bloxawys-setup.exe)

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

</div>

## Screenshots

<div align="center">
<img src="docs/screenshots/multi.png" alt="Two Roblox windows on different accounts with BloxAwys" width="800">
<br><br>
<img src="docs/screenshots/main.png" alt="BloxAwys main window" width="320">
</div>

## Features

- Keep several Roblox windows open on different accounts. A new window doesn't close the previous ones.
- Accounts are saved in a list. You sign in once, then start Roblox with the ▶ button, no password needed.
- Tick several accounts and launch them in one go.
- Paste a game link or Place ID and the windows open straight in that game. Without a link you get the Roblox home screen.
- You type your login and password on roblox.com in a built-in window; the client doesn't see or store them.
- Sessions are kept only on your computer, encrypted.
- Macros: record keyboard and mouse in a Roblox window, save them and loop them. Each window can run its own macro. Turn them on in the settings. Keep in mind that many games forbid macros in their rules.
- Anti-AFK keeps Roblox from disconnecting you after 20 minutes of inactivity: every few minutes it turns the camera, takes a step or jumps in every window. Turn it on in the settings.
- If Roblox resets a sign-in, the account gets a "Sign in again" button.
- Works with Bloxstrap and Fishstrap: it finds the Roblox they installed and starts it directly.

The app interface is in Russian for now.

## Installation

1. Download [`bloxawys-setup.exe`](https://github.com/Axawys/BloxAwys/releases/latest/download/bloxawys-setup.exe) (also available on the [latest release](https://github.com/Axawys/BloxAwys/releases/latest) page).
2. Run the installer. If you see "Windows protected your PC", click "More info", then "Run anyway". Windows shows this because the app doesn't have a paid code signature.
3. Open BloxAwys, click "Войти и запустить Roblox" (Sign in and launch Roblox) and sign in.

Add your other accounts the same way. After that, pick accounts in the list and launch them.

BloxAwys has to stay open while Roblox windows are open. If you close it, the next Roblox window will close the previous ones.

## Security

The client only talks to Roblox servers and has no servers of its own. Sessions are encrypted with Windows DPAPI and tied to your Windows account, so they can't be decrypted on another computer or by another user. The code is open and lives in this repository. Each release page has a VirusTotal report and the installer checksum.

A session gives full access to the account, so don't share the files in `%APPDATA%\com.axawys` with anyone.

## FAQ

<details>
<summary>Roblox windows still close each other</summary>

Most likely Roblox was already open when BloxAwys started, for example from startup. The client then shows a red warning: click "Закрыть другие клиенты" (Close other clients) in it and launch your accounts from BloxAwys. If that doesn't help, another program such as Bloxstrap is holding Roblox: close it and restart BloxAwys.
</details>

<details>
<summary>An account says the session has expired</summary>

This happens if you click "Log out" inside Roblox, change the password, or end sessions in the account settings. Click "Sign in again" and sign in once more.
</details>

<details>
<summary>"Roblox is not installed"</summary>

Install Roblox from [roblox.com](https://www.roblox.com/download) and click "Check". A regular install, Bloxstrap and Fishstrap all work.
</details>

## Technical details

<details>
<summary>How it works</summary>

Sign-in happens in an embedded WebView2 showing `roblox.com/login`. Each sign-in gets a temporary profile. Once you're signed in, the client takes the `.ROBLOSECURITY` cookie and deletes the profile. It doesn't log out, because that would invalidate the cookie.

Accounts are stored with `flutter_secure_storage` (DPAPI) in `%APPDATA%\com.axawys\bloxawys\flutter_secure_storage.dat`.

To launch, the client exchanges the cookie for a one-time ticket (`auth.roblox.com/v1/authentication-ticket`) and starts `RobloxPlayerBeta.exe` with it directly. It doesn't use the `roblox-player:` protocol, so Bloxstrap can't intercept the launch. If Roblox sends back a refreshed cookie, the client saves it.

To keep windows from closing each other, the client creates `ROBLOX_singletonMutex` and `ROBLOX_singletonEvent` on startup and holds them while it's open (`lib/services/multi_instance.dart`).

When several accounts are launched, there's a 2-second pause between them.

Anti-AFK (`lib/services/anti_afk.dart`, `lib/services/roblox_windows.dart`) finds the windows of `RobloxPlayerBeta.exe` processes, activates each in turn, presses keys via `SendInput` with scan codes, then gives focus back. If the user touched the mouse or keyboard in the last 30 seconds, the press is postponed. Settings live in `%APPDATA%\com.axawys\bloxawys\settings.json`.

Macros are recorded with Raw Input (`lib/services/raw_input.dart`): a hidden message-only window receives input with the `RIDEV_INPUTSINK` flag, no global keyboard hooks are used. Only input from real devices is recorded, and only while the chosen Roblox window is active: keys as scan codes, mouse movement as relative deltas, clicks with a point in fractions of the window size. Playback (`lib/services/macro_player.dart`) runs the actions of all macros in time order and switches focus before an action for another window; held keys are released and pressed again around the switch. F8 ends recording and stops macros. Macros are stored in `macros.json` next to the settings.

</details>

<details>
<summary>Building on Windows</summary>

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop).
2. Install Visual Studio 2022 with the "Desktop development with C++" workload.
3. Install the NuGet CLI, which the WebView plugin needs: `winget install Microsoft.NuGet`, then restart the terminal.
4. Turn on Windows Developer Mode (Settings → System → For developers). Without it Flutter can't create symlinks for plugins.
5. In the project folder:
   ```
   flutter pub get
   flutter run -d windows
   ```
   For a release build run `flutter build windows`; the files end up in `build\windows\x64\runner\Release\`.

To run the build on another computer, put `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll` next to `bloxawys.exe`, or install the Visual C++ Redistributable there. WebView2 Runtime usually comes with Windows 10 and 11.

</details>

<details>
<summary>Project structure</summary>

```
lib/
├── main.dart                  entry point
├── app_controller.dart        app state: accounts, launching
├── models/
│   ├── account.dart           saved account
│   ├── macro.dart             a macro and its actions
│   └── settings.dart          app settings
├── services/
│   ├── account_store.dart     encrypted storage
│   ├── settings_store.dart    settings (settings.json)
│   ├── anti_afk.dart          anti-AFK schedule
│   ├── roblox_windows.dart    Roblox windows: focus and key presses
│   ├── win32.dart             WinAPI bindings
│   ├── raw_input.dart         Raw Input and the F8 key
│   ├── macro_recorder.dart    recording a macro
│   ├── macro_player.dart      playing macros in windows
│   ├── macro_store.dart       saved macros (macros.json)
│   ├── roblox_api.dart        Roblox API: user, avatars, ticket
│   ├── roblox_launcher.dart   finding and launching RobloxPlayerBeta.exe
│   └── multi_instance.dart    multiple Roblox windows
└── ui/
    ├── home_page.dart         main window
    ├── login_page.dart        sign-in window (WebView2)
    ├── macros_page.dart       macros
    └── settings_page.dart     settings
```

</details>

## License

[GNU GPL v3](LICENSE). You can use, modify and share the code, but modified versions have to be published as open source under GPLv3 too.

<sub>BloxAwys is not affiliated with Roblox Corporation. Roblox is a trademark of Roblox Corporation.</sub>
