#!/usr/bin/env bash
# Install Theos, the Linux iOS toolchain, ldid, and the iOS 16.5 SDK.
# Safe to re-run. macOS developers with Xcode can skip this and use
# a normal Theos install; GitHub Actions uses this script.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This helper installs the Linux toolchain. On macOS, install Theos and an iOS SDK, then run make." >&2
  exit 1
fi

export THEOS="${THEOS:-$HOME/theos}"
SDK_NAME="iPhoneOS16.5.sdk"
CLANG="$THEOS/toolchain/linux/iphone/bin/clang"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential fakeroot rsync curl git perl zip unzip xz-utils \
  libtinfo6 libncurses6 python3 ca-certificates dpkg binutils libplist-utils

if [[ -x "$CLANG" && -d "$THEOS/sdks/$SDK_NAME" && -x "$THEOS/bin/ldid" ]]; then
  echo "Theos already installed at $THEOS"
  "$CLANG" --version
  exit 0
fi

if [[ ! -d "$THEOS/.git" ]]; then
  rm -rf "$THEOS"
  git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

mkdir -p "$THEOS/toolchain" "$THEOS/sdks" "$THEOS/bin"

if [[ ! -x "$CLANG" ]]; then
  arch="$(uname -m)"
  tmp="$(mktemp)"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp" \
    "https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-${arch}.tar.xz"
  tar -xJf "$tmp" -C "$THEOS/toolchain"
  rm -f "$tmp"
fi

if [[ ! -d "$THEOS/sdks/$SDK_NAME" ]]; then
  tmp="$(mktemp)"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp" \
    "https://github.com/theos/sdks/releases/download/master-146e41f/${SDK_NAME}.tar.xz"
  tar -xJf "$tmp" -C "$THEOS/sdks"
  rm -f "$tmp"
fi

if [[ ! -x "$THEOS/bin/ldid" ]]; then
  case "$(uname -m)" in
    x86_64) ldid_asset="ldid_linux_x86_64" ;;
    aarch64 | arm64) ldid_asset="ldid_linux_aarch64" ;;
    *) echo "Unsupported architecture for ldid: $(uname -m)" >&2; exit 1 ;;
  esac
  tmp="$(mktemp)"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp" \
    "https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/${ldid_asset}"
  install -m 0755 "$tmp" "$THEOS/bin/ldid"
  rm -f "$tmp"
fi

test -x "$CLANG"
test -d "$THEOS/sdks/$SDK_NAME"
"$CLANG" --version
echo "THEOS=$THEOS"
