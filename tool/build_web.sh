#!/usr/bin/env bash
# Builds the web version (a PWA for iPhone testers) into build/web.
#
# SQLite's WebAssembly build and sqflite's shared worker aren't committed
# (no binaries in git), so this fetches them first.
#
# Usage: tool/build_web.sh [base-href]
#   base-href defaults to "/". GitHub Pages project sites need "/<repo>/".
set -euo pipefail
cd "$(dirname "$0")/.."

base_href="${1:-/}"

flutter pub get

# Compiles web/sqflite_sw.js from the locked package versions (and downloads
# a sqlite3.wasm we replace below).
dart run sqflite_common_ffi_web:setup --force

# The setup tool's wasm version is hard-coded. Use the one that matches the
# sqlite3 package in pubspec.lock instead.
version=$(awk '/^  sqlite3:/ {found=1} found && /version:/ {gsub(/"/, "", $2); print $2; exit}' pubspec.lock)
echo "Fetching sqlite3.wasm $version"
curl -fsSL -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$version/sqlite3.wasm"

flutter build web --release --base-href "$base_href" --no-wasm-dry-run
