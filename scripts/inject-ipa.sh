#!/usr/bin/env bash
# Inject a built TikSpice .deb into a decrypted IPA with cyan (pyzule-rw).
# The patched IPA is fakesigned and thinned to arm64. Re-sign it with your
# own certificate before installing (Sideloadly, AltStore, Feather, or TrollStore).
set -euo pipefail

INPUT=""
TWEAK=""
OUTPUT=""
NAME=""
BUNDLE=""
PLIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="${2:-}"; shift 2 ;;
    --tweak) TWEAK="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --bundle-id) BUNDLE="${2:-}"; shift 2 ;;
    --plist) PLIST="${2:-}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$INPUT" || -z "$TWEAK" || -z "$OUTPUT" ]]; then
  echo "Usage: inject-ipa.sh --input app.ipa --tweak TikSpice.deb --output out.ipa [--name Display] [--bundle-id id] [--plist extra.plist]" >&2
  exit 2
fi

if [[ ! -f "$INPUT" ]]; then
  echo "IPA not found: $INPUT" >&2
  exit 1
fi
if [[ ! -f "$TWEAK" ]]; then
  echo "Tweak package not found: $TWEAK" >&2
  exit 1
fi
if ! command -v cyan >/dev/null 2>&1; then
  echo "cyan is not on PATH. Install it with: pipx install --force https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip" >&2
  exit 1
fi

if [[ -n "$BUNDLE" && ! "$BUNDLE" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+$ ]]; then
  echo "Bundle id may only contain letters, numbers, dots, and hyphens." >&2
  exit 2
fi

magic="$(od -An -t x1 -N 2 "$INPUT" | tr -d ' \n')"
if [[ "$magic" != "504b" ]]; then
  echo "Input is not a zip/IPA archive." >&2
  exit 1
fi

args=(-i "$INPUT" -o "$OUTPUT" -f "$TWEAK" -s -q --overwrite)
if [[ -n "$PLIST" ]]; then
  args+=(-l "$PLIST")
fi
if [[ -n "$NAME" ]]; then
  args+=(-n "$NAME")
fi
if [[ -n "$BUNDLE" ]]; then
  args+=(-b "$BUNDLE")
fi

cyan "${args[@]}"

if [[ ! -f "$OUTPUT" ]]; then
  echo "cyan did not write $OUTPUT" >&2
  exit 1
fi

if ! unzip -l "$OUTPUT" | grep -q "TikSpice.dylib"; then
  echo "Patched IPA is missing TikSpice.dylib" >&2
  exit 1
fi

echo "Wrote $OUTPUT"
