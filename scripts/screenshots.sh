#!/usr/bin/env bash
# Встановлює зібраний додаток у симулятор, відкриває кожну вкладку з демо-даними та робить скриншоти.
# Використання: scripts/screenshots.sh <UDID> <шлях до .app> <тека для скриншотів>
set -euo pipefail

UDID="$1"
APP="$2"
OUT="$3"
BUNDLE_ID="ua.businesscompass.app"

mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 || true
xcrun simctl install "$UDID" "$APP"

shot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@"
  sleep 8
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png"
  echo "📸 $name"
}

xcrun simctl ui "$UDID" appearance light
shot 01-onboarding
# Прогрів: перший запуск з демо-даними довший (кеші шрифтів, Charts) — без скриншота.
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" -uiDemo YES -uiTab dashboard
sleep 12
shot 02-dashboard     -uiDemo YES -uiTab dashboard
shot 03-finance       -uiDemo YES -uiTab finance
shot 04-taxes         -uiDemo YES -uiTab taxes
shot 05-opportunities -uiDemo YES -uiTab opportunities
shot 06-advisor       -uiDemo YES -uiTab advisor

shot 09-forms         -uiDemo YES -uiTab advisor -uiAdvisorMode "Документи"
shot 10-startup-guide -uiDemo YES -uiTab advisor -uiAdvisorMode "Відкриття"
shot 11-invoices      -uiDemo YES -uiTab finance -uiScreen invoices
shot 12-invoice-qr    -uiDemo YES -uiTab finance -uiScreen invoice
shot 13-import        -uiDemo YES -uiTab finance -uiScreen import
shot 14-declaration   -uiDemo YES -uiTab taxes -uiScreen declaration
shot 15-splash        -uiDemo YES -uiSplashHold YES

xcrun simctl ui "$UDID" appearance dark
shot 07-dashboard-dark -uiDemo YES -uiTab dashboard
shot 08-taxes-dark     -uiDemo YES -uiTab taxes
