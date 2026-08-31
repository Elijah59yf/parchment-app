#!/usr/bin/env bash
#
# rename_package.sh — renames the Flutter app's package/bundle
# identifier (Android applicationId/namespace, iOS/macOS
# PRODUCT_BUNDLE_IDENTIFIER, Linux APPLICATION_ID) across every
# platform in one shot.
#
# This does NOT touch the app's display name ("Parchment") anywhere —
# only the reverse-DNS identifier (e.g. com.example.parchment) used
# internally by app stores, Firebase, etc. Run rename_app_name.sh
# separately if you ever want that too.
#
# Usage:
#   ./scripts/rename_package.sh com.monarch.parchment
#   ./scripts/rename_package.sh com.monarch.parchment com.example.parchment
#
#   arg1 (required): the NEW package id
#   arg2 (optional): the OLD package id to search for. If omitted,
#                     it's auto-detected from android/app/build.gradle.kts.
#
# Must be run from the Flutter project root (the folder containing
# pubspec.yaml, android/, ios/, etc.) — same directory this script's
# parent `scripts/` folder lives in.
#
# Safe to re-run: if OLD == NEW, or if OLD isn't found anywhere, it
# exits cleanly without touching anything.

set -euo pipefail

# ---------------------------------------------------------------
# 0. Args + sanity checks
# ---------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <new.package.id> [old.package.id]" >&2
  exit 1
fi

NEW_PKG="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Error: pubspec.yaml not found in $PROJECT_ROOT — run this from the Flutter project root." >&2
  exit 1
fi

GRADLE_FILE="android/app/build.gradle.kts"

if [[ $# -ge 2 ]]; then
  OLD_PKG="$2"
else
  if [[ ! -f "$GRADLE_FILE" ]]; then
    echo "Error: $GRADLE_FILE not found — pass the old package id explicitly as arg 2." >&2
    exit 1
  fi
  OLD_PKG="$(grep -m1 'applicationId' "$GRADLE_FILE" | sed -E 's/.*"([^"]+)".*/\1/')"
  if [[ -z "$OLD_PKG" ]]; then
    echo "Error: couldn't auto-detect the current applicationId from $GRADLE_FILE — pass it explicitly as arg 2." >&2
    exit 1
  fi
fi

# Basic reverse-DNS shape check — catches obvious typos (missing dots,
# stray spaces) before they get baked into a dozen files.
if [[ ! "$NEW_PKG" =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$ ]]; then
  echo "Error: '$NEW_PKG' doesn't look like a valid package id (expected e.g. com.monarch.parchment)." >&2
  exit 1
fi

if [[ "$OLD_PKG" == "$NEW_PKG" ]]; then
  echo "Old and new package id are already the same ($OLD_PKG) — nothing to do."
  exit 0
fi

echo "Renaming package id:"
echo "  $OLD_PKG  ->  $NEW_PKG"
echo

# Portable in-place sed: BSD sed (macOS) requires -i '' , GNU sed (Linux) requires -i
sed_i() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"          # GNU sed
  else
    sed -i '' "$@"        # BSD sed
  fi
}

OLD_ESCAPED="$(printf '%s' "$OLD_PKG" | sed 's/\./\\./g')"
CHANGED_FILES=()

# ---------------------------------------------------------------
# 1. Android — namespace + applicationId, and moving MainActivity.kt
#    to match the new package folder structure (its `package` line
#    must match its own directory path or the build fails).
# ---------------------------------------------------------------
if [[ -f "$GRADLE_FILE" ]]; then
  sed_i "s/$OLD_ESCAPED/$NEW_PKG/g" "$GRADLE_FILE"
  CHANGED_FILES+=("$GRADLE_FILE")
fi

OLD_KOTLIN_DIR="android/app/src/main/kotlin/$(echo "$OLD_PKG" | tr '.' '/')"
NEW_KOTLIN_DIR="android/app/src/main/kotlin/$(echo "$NEW_PKG" | tr '.' '/')"

if [[ -d "$OLD_KOTLIN_DIR" ]]; then
  mkdir -p "$NEW_KOTLIN_DIR"
  for f in "$OLD_KOTLIN_DIR"/*.kt; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    sed "s/^package $OLD_ESCAPED\$/package $NEW_PKG/" "$f" > "$NEW_KOTLIN_DIR/$base"
    rm "$f"
    CHANGED_FILES+=("$NEW_KOTLIN_DIR/$base (new)")
  done
  # Clean up the old, now-empty package directory chain, but only if
  # actually empty — never force-delete something unexpected is in there.
  rmdir -p "$OLD_KOTLIN_DIR" 2>/dev/null || true
fi

# Same treatment for Java, in case this project (or a fork of it) uses
# Java instead of Kotlin for MainActivity.
OLD_JAVA_DIR="android/app/src/main/java/$(echo "$OLD_PKG" | tr '.' '/')"
NEW_JAVA_DIR="android/app/src/main/java/$(echo "$NEW_PKG" | tr '.' '/')"
if [[ -d "$OLD_JAVA_DIR" ]]; then
  mkdir -p "$NEW_JAVA_DIR"
  for f in "$OLD_JAVA_DIR"/*.java; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    sed "s/^package $OLD_ESCAPED;\$/package $NEW_PKG;/" "$f" > "$NEW_JAVA_DIR/$base"
    rm "$f"
    CHANGED_FILES+=("$NEW_JAVA_DIR/$base (new)")
  done
  rmdir -p "$OLD_JAVA_DIR" 2>/dev/null || true
fi

# google-services.json (if already present) is keyed to the OLD
# package - it'll silently mismatch rather than error, so flag it
# instead of trying to auto-fix a file with real Firebase credentials.
if [[ -f "android/app/google-services.json" ]] && grep -q "$OLD_PKG" "android/app/google-services.json" 2>/dev/null; then
  echo "⚠ android/app/google-services.json still references $OLD_PKG."
  echo "  Re-download it from the Firebase console after re-registering"
  echo "  (or adding) the Android app under $NEW_PKG — don't hand-edit it."
  echo
fi

# ---------------------------------------------------------------
# 2. iOS + macOS — PRODUCT_BUNDLE_IDENTIFIER in the Xcode project
#    files and the macOS xcconfig. Test-target ids (which carry a
#    ".RunnerTests" suffix off the base id) update automatically
#    since they're derived via simple substring replacement.
# ---------------------------------------------------------------
for f in ios/Runner.xcodeproj/project.pbxproj \
         macos/Runner.xcodeproj/project.pbxproj \
         macos/Runner/Configs/AppInfo.xcconfig; do
  if [[ -f "$f" ]]; then
    sed_i "s/$OLD_ESCAPED/$NEW_PKG/g" "$f"
    CHANGED_FILES+=("$f")
  fi
done

# ---------------------------------------------------------------
# 3. Linux — APPLICATION_ID in CMakeLists.txt
# ---------------------------------------------------------------
if [[ -f "linux/CMakeLists.txt" ]]; then
  sed_i "s/$OLD_ESCAPED/$NEW_PKG/g" "linux/CMakeLists.txt"
  CHANGED_FILES+=("linux/CMakeLists.txt")
fi

# ---------------------------------------------------------------
# 4. Windows — the MSIX/App identity, if this project has one
#    (harmless no-op if it doesn't).
# ---------------------------------------------------------------
if [[ -f "windows/runner/Runner.rc" ]] && grep -q "$OLD_ESCAPED" "windows/runner/Runner.rc" 2>/dev/null; then
  sed_i "s/$OLD_ESCAPED/$NEW_PKG/g" "windows/runner/Runner.rc"
  CHANGED_FILES+=("windows/runner/Runner.rc")
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo "Done. Files touched:"
for f in "${CHANGED_FILES[@]}"; do
  echo "  - $f"
done
echo
echo "Next steps:"
echo "  1. flutter clean"
echo "  2. If using Firebase: re-register (or add) the app under $NEW_PKG"
echo "     in the Firebase console and drop the new google-services.json"
echo "     into android/app/ (and GoogleService-Info.plist into ios/Runner/)."
echo "  3. flutter pub get && flutter run"
