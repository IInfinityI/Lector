#!/usr/bin/env bash
# ============================================================================
#  run-on-phone.sh — полный цикл: собрать проект и доставить на телефон
#
#  Использование:
#      ./run-on-phone.sh              # сборка debug APK -> установка -> запуск
#      ANDROID_HOME=/opt/android-sdk ./run-on-phone.sh   # если SDK не в PATH
#
#  Требуется: подключённый по USB (или Wi-Fi adb connect) телефон с ADB.
#  Шаги:
#    1. gradlew assembleDebug          — сборка всего проекта
#    2. adb install -r                 — установка APK на устройство
#    3. adb shell am start             — открытие приложения на телефоне
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

# --- Android SDK ------------------------------------------------------------
if [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  for cand in /opt/android-sdk "$HOME/Android/Sdk" "/usr/lib/android-sdk"; do
    if [ -d "$cand" ]; then export ANDROID_HOME="$cand"; break; fi
  done
fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
ADB=""
if [ -n "$SDK" ] && [ -x "$SDK/platform-tools/adb" ]; then
  ADB="$SDK/platform-tools/adb"
elif command -v adb >/dev/null 2>&1; then
  ADB="$(command -v adb)"
fi

APK="app/build/outputs/apk/debug/app-debug.apk"
PKG="com.example.lector"
ACTIVITY="$PKG/.MainActivity"

# Ключевое: сначала полностью удаляем старое приложение с телефона.
# Именно из-за остатков старого шаблонного APK на экране мог висеть «Hello Android!»,
# даже когда код проекта уже починен (Android иногда не перезапускает процесс,
# если пакет обновился «на живую»).
if [ -n "$ADB" ] && "$ADB" devices 2>/dev/null | grep -q "device$"; then
  echo "==> 0/3 Удаляю СТАРУЮ версию $PKG с телефона (если установлена)..."
  "$ADB" uninstall "$PKG" >/dev/null 2>&1 || true
fi

echo "==> 1/3 Сборка проекта с нуля (clean assembleDebug)..."
./gradlew clean assembleDebug

if [ ! -f "$APK" ]; then
  echo "ERROR: APK не найден: $APK" >&2
  exit 1
fi
echo "    Готово: $APK ($(du -h "$APK" | cut -f1))"

# --- Device -----------------------------------------------------------------
if [ -z "$ADB" ]; then
  echo "WARNING: adb не найден (установите platform-tools)." >&2
  echo "APK собран вручную установите: adb install -r $APK" >&2
  exit 0
fi

echo "==> 2/3 Поиск устройства и установка..."
"$ADB" devices | grep -q "device$" || {
  echo "Устройство не найдено. Подключите телефон по USB (разрешите отладку)" >&2
  echo "или включите беспроводную отладку: adb pair <ip:port> && adb connect <ip:port>" >&2
  exit 1
}
"$ADB" install -r "$APK"

echo "==> 3/3 Запуск приложения на телефоне..."
"$ADB" shell am start -n "$ACTIVITY" >/dev/null
echo "Готово: $PKG запущен на устройстве."
