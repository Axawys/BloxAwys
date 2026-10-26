#!/usr/bin/env bash
# Собирает и запускает демо-версию интерфейса на Linux (см. lib/main_demo.dart).
# Аргумент --real запускает обычный lib/main.dart вместо демо.
set -euo pipefail
cd "$(dirname "$0")"

target=lib/main_demo.dart
[[ "${1:-}" == "--real" ]] && target=lib/main.dart

flutter pub get
flutter build linux --release -t "$target"

bin="$PWD/build/linux/x64/release/bundle/bloxawys"

# В Hyprland окно по умолчанию растягивается тайлингом, поэтому открываем его
# плавающим и того же размера, что на Windows (520x760).
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null; then
  # Сначала синтаксис Lua-конфига (Hyprland 0.55+), затем старый.
  if [[ "$(hyprctl dispatch "hl.dsp.exec_cmd(\"$bin\", {float = true, size = {520, 760}, center = true})" 2>&1)" != ok ]]; then
    hyprctl dispatch exec "[float; size 520 760; center] $bin" >/dev/null
  fi
else
  "$bin"
fi
