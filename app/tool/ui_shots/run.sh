#!/usr/bin/env bash
# Takes the UI screenshots.
#   tool/ui_shots/run.sh <out dir> [extra flutter test args]
# Needs flutter on PATH (or FLUTTER_ROOT set), Flutter 3.38.3.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:?out dir}"
mkdir -p "$out"
flutter="${FLUTTER_ROOT:+$FLUTTER_ROOT/bin/}flutter"
export FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")}"
UI_SHOTS=1 UI_SHOTS_OUT="$(cd "$out" && pwd)" TZ=Australia/Sydney \
  "$flutter" test test/ui_shots/shots_test.dart --tags ui_shots --reporter expanded "${@:2}"
