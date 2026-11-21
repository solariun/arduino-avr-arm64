#!/bin/sh
# Package a built toolchain into a relocatable tarball + sha256.
#   ./package.sh [TOOLCHAIN_DIR]        # default: ~/.local/avr
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
TC=$(cd "${1:-$HOME/.local/avr}" && pwd)
VER=$("$TC/bin/avr-gcc" -dumpversion)
NAME="avr-gcc-$VER-$(uname -s | tr A-Z a-z)-$(uname -m)"
mkdir -p "$HERE/dist"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$TC" "$STAGE/$NAME"
# refuse to ship binaries that depend on non-system dylibs
bad=$(find "$STAGE/$NAME" -type f -perm +111 -exec sh -c 'file -b "$1" | grep -q Mach-O && otool -L "$1"' _ {} \; \
      | grep -E "^\s+/(opt|usr/local)/" | sort -u || true)
[ -z "$bad" ] || { echo "error: non-system dylib dependencies:"; echo "$bad"; exit 1; }
tar -C "$STAGE" -cJf "$HERE/dist/$NAME.tar.xz" "$NAME"
(cd "$HERE/dist" && shasum -a 256 "$NAME.tar.xz" > "$NAME.tar.xz.sha256")
ls -lh "$HERE/dist/$NAME.tar.xz"
cat "$HERE/dist/$NAME.tar.xz.sha256"
