#!/bin/sh
# Builds the check page, starts Auth and Firestore emulators, and runs it in headless Chrome.
set -e
cd "$(dirname "$0")/.."
flutter --suppress-analytics build web -t tool/client_emulator_check.dart -o build/client_check --no-tree-shake-icons > /dev/null
firebase emulators:exec --project demo-foodienoms --only auth,firestore \
  "node tool/seed_client_test.js && node tool/client_check_runner.js \"$PWD/build/client_check\""
