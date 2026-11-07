#!/bin/sh
# Auth-only local email outbox; no real emails or production users are changed.
set -e
cd "$(dirname "$0")/.."
flutter --suppress-analytics build web -t tool/password_reset_emulator_check.dart -o build/password_reset_check --no-tree-shake-icons > /dev/null
firebase emulators:exec --project demo-foodienoms --only auth \
  "node tool/client_check_runner.js \"$PWD/build/password_reset_check\""
