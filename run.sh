#!/usr/bin/env bash
#
# Build and launch FloatingAI. Kills any previous instance first so
# Accessibility / clipboard state starts clean.
#
set -euo pipefail

CONFIG="${1:-debug}"
APP_NAME="FloatingAI"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$ROOT/build.sh" "$CONFIG"

echo "==> Relaunching"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.3
open "$ROOT/build/$APP_NAME.app"
echo "Launched. Look for the floating 'AI' widget on the right edge of your screen."
