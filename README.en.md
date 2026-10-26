<div align="center">

<img src="assets/icon/app_icon.png" alt="BloxAwys" width="128">

# BloxAwys

**Multiple Roblox accounts, multiple windows, one-click launch.**

[Русский](README.md) · **English**

[![Download](https://img.shields.io/github/v/release/Axawys/BloxAwys?label=Download&style=for-the-badge&color=3B82F6)](https://github.com/Axawys/BloxAwys/releases/latest)

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

</div>

---

## Screenshots

<div align="center">
<img src="docs/screenshots/main.png" alt="Main window" width="300">
&nbsp;&nbsp;
<img src="docs/screenshots/login.png" alt="Signing in" width="300">
<br><br>
<img src="docs/screenshots/multi.png" alt="Several Roblox windows at once" width="720">
</div>

## Features

- 🪟 **Several Roblox windows at once.** Each window runs its own account, and new windows don't close the old ones.
- 👥 **All accounts in one list.** Sign in once, then launch Roblox with the ▶ button, no password needed.
- 🚀 **Batch launch.** Tick the accounts you need and launch them all together.
- 🎮 **Straight into a game.** Paste a game link or Place ID and every window opens in that game. Without a link, the Roblox home screen opens.
- 🔐 **Sign in on the official site.** You enter your login and password on roblox.com in a built-in window. The client never sees or stores them.
- 🛡️ **Encrypted data.** Sessions are stored only on your computer, encrypted.
- 🔔 **Expired session warnings.** If Roblox resets a sign-in, the account shows "Sign in again".
- 🧩 **Works alongside Bloxstrap and Fishstrap.** Finds the Roblox they installed and launches it directly.

> [!NOTE]
> The app interface is currently in Russian only.

## Installation

1. Download `setup.exe` from the [latest release](https://github.com/Axawys/BloxAwys/releases/latest).
2. Run the installer.
   If Windows shows "Windows protected your PC", click **"More info" → "Run anyway"**. This appears because the app has no paid code signature.
3. Open BloxAwys, click **"Войти и запустить Roblox"** (Sign in and launch Roblox) and sign in.

Repeat the sign-in for your other accounts. After that, pick accounts in the list and launch them.

> [!IMPORTANT]
> Keep BloxAwys open while Roblox windows are open. Without it, the next Roblox window closes the previous ones.

## Security

- The client talks only to Roblox servers. No servers of its own, no analytics, no ads.
- Account sessions are encrypted with Windows DPAPI and tied to your Windows user: they can't be decrypted on another computer or by another user.
- The source code is open, right here. Every release page has a VirusTotal report and the installer checksum.

> [!WARNING]
> An account session gives full access to the account. Never share BloxAwys files from `%APPDATA%\com.axawys`.

## FAQ

<details>
<summary><b>Roblox windows still close each other</b></summary>

Most likely Roblox was open before BloxAwys started; the client shows a warning about this. Close all Roblox windows, restart BloxAwys and launch accounts from it.
</details>

<details>
<summary><b>An account says the session has expired</b></summary>

This happens if you click "Log out" inside Roblox, change the password, or end sessions in the account settings. Click "Sign in again" and sign in once more.
</details>

<details>
<summary><b>"Roblox is not installed"</b></summary>

Install Roblox from [roblox.com](https://www.roblox.com/download) and click "Check". Regular installs, Bloxstrap and Fishstrap are supported.
</details>

---

## Technical details

<details>
<summary><b>How it works</b></summary>

- **Sign-in.** The sign-in window is an embedded WebView2 showing `roblox.com/login`, with a temporary profile for every sign-in. After sign-in the client takes the `.ROBLOSECURITY` cookie and deletes the profile. It does not log out, since that would invalidate the cookie.
- **Storage.** Accounts are stored with `flutter_secure_storage` (DPAPI) in `%APPDATA%\com.axawys\bloxawys\flutter_secure_storage.dat`.
- **Launch.** The cookie is exchanged for a one-time ticket (`auth.roblox.com/v1/authentication-ticket`), which is passed straight to `RobloxPlayerBeta.exe`. The `roblox-player:` protocol is not used, so Bloxstrap can't intercept it. If Roblox rotates the cookie in the response, the client saves the new one.
- **Multiple windows.** On startup the client creates `ROBLOX_singletonMutex` and `ROBLOX_singletonEvent` and holds them while it's open (`lib/services/multi_instance.dart`).
- **Batch launch.** Accounts launch one by one with a 2-second pause so the windows don't interfere with each other.

</details>

<details>
<summary><b>Building on Windows</b></summary>

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop).
2. Install Visual Studio 2022 with the **"Desktop development with C++"** workload.
3. Install the NuGet CLI, which the WebView plugin needs: `winget install Microsoft.NuGet`, then restart the terminal.
4. Turn on Windows **Developer Mode** (Settings → System → For developers). Without it Flutter can't create symlinks for plugins.
5. In the project folder:
   ```
   flutter pub get
   flutter run -d windows
   ```
   Release build: `flutter build windows`, output in `build\windows\x64\runner\Release\`.

To run on another computer, `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll` must sit next to `bloxawys.exe` (or the Visual C++ Redistributable must be installed). WebView2 Runtime usually ships with Windows 10/11.

</details>

<details>
<summary><b>Previewing the UI on Linux</b></summary>

```
./run_linux.sh
```

The script builds a demo version (`lib/main_demo.dart`) and opens a 520×760 window like on Windows; floating on Hyprland. The demo has three in-memory test accounts, and "launching" only shows a spinner. Sign-in and launching Roblox don't work on Linux: there's no WebView2 and no Roblox. The theme is built for Windows and uses Segoe UI; if it isn't installed, the system font is used.

`./run_linux.sh --real` runs the regular version instead of the demo.

</details>

<details>
<summary><b>Project structure</b></summary>

```
lib/
├── main.dart                  entry point
├── main_demo.dart             demo mode for UI checks
├── app_controller.dart        app state: accounts, launching
├── models/account.dart        saved account
├── services/
│   ├── account_store.dart     encrypted storage
│   ├── roblox_api.dart        Roblox API: user, avatars, ticket
│   ├── roblox_launcher.dart   finding and launching RobloxPlayerBeta.exe
│   └── multi_instance.dart    multiple Roblox windows
└── ui/
    ├── home_page.dart         main window
    └── login_page.dart        sign-in window (WebView2)
```

</details>

## License

[GNU GPL v3](LICENSE). You're free to use, modify and share the code, but modified versions must also be released as open source under GPLv3.

---

<div align="center">
<sub>BloxAwys is not affiliated with Roblox Corporation. Roblox is a trademark of Roblox Corporation.</sub>
</div>
