#!/bin/sh
# Keep things in sync with the original upstream sources.
#
#   ./update.sh                    update the Arduino AVR core from Arduino's official
#                                  package index, re-apply platform.local.txt, run tests
#   ./update.sh --check-toolchain  compare the binutils/gcc/avr-libc versions pinned in
#                                  build.sh with the latest upstream releases (read-only)
#   ./update.sh --all              both
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)

core_update() {
    command -v arduino-cli >/dev/null || { echo "error: arduino-cli not found" >&2; exit 1; }
    echo "==> refreshing Arduino package index"
    arduino-cli core update-index
    before=$(arduino-cli core list | awk '$1=="arduino:avr"{print $2}')
    if [ -z "$before" ]; then
        echo "==> installing arduino:avr"
        arduino-cli core install arduino:avr
    else
        echo "==> upgrading arduino:avr (installed: $before)"
        arduino-cli core upgrade arduino:avr || true
    fi
    after=$(arduino-cli core list | awk '$1=="arduino:avr"{print $2}')
    [ "$before" = "$after" ] && echo "arduino:avr $after is already the latest" || echo "arduino:avr $before -> $after"

    echo "==> re-applying platform.local.txt"
    "$HERE/install.sh" "${TOOLCHAIN:-$HOME/.local/avr}"

    # drop overrides left in core versions that are no longer installed by arduino-cli
    DATA=$(arduino-cli config get directories.data 2>/dev/null || echo "$HOME/Library/Arduino15")
    for core in "$DATA"/packages/arduino/hardware/avr/*/; do
        v=$(basename "$core")
        [ "$v" = "$after" ] && continue
        echo "note: old core folder still present: $core (arduino-cli normally removes it after an upgrade)"
    done

    echo "==> testing"
    "$HERE/test.sh" arduino:avr:nano
}

latest_gnu() { # name -> newest version on ftp.gnu.org
    case $1 in
        gcc) curl -fsL https://ftp.gnu.org/gnu/gcc/ | grep -oE 'gcc-[0-9]+\.[0-9]+\.[0-9]+/' | tr -d / | sed 's/gcc-//' ;;
        binutils) curl -fsL https://ftp.gnu.org/gnu/binutils/ | grep -oE 'binutils-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz' | sed 's/binutils-//; s/\.tar\.xz//' ;;
    esac | sort -t. -k1,1n -k2,2n -k3,3n | uniq | tail -1
}

latest_avrlibc() {
    curl -fsL https://api.github.com/repos/avrdudes/avr-libc/releases/latest \
        | grep -oE '"tag_name": *"[^"]+"' | grep -oE 'avr-libc-[0-9_]+' | sed 's/avr-libc-//; s/_release//; s/_/./g; s/\.$//'
}

pinned() { grep -E "^$1=" "$HERE/build.sh" | cut -d= -f2; }

toolchain_check() {
    echo "==> checking upstream toolchain releases"
    outdated=0
    for c in "binutils BINUTILS_V" "gcc GCC_V" "avr-libc LIBC_V"; do
        set -- $c
        have=$(pinned "$2")
        if [ "$1" = avr-libc ]; then new=$(latest_avrlibc); else new=$(latest_gnu "$1"); fi
        if [ -z "$new" ]; then printf '  %-9s pinned %-8s latest: (could not check)\n' "$1" "$have"; continue; fi
        if [ "$new" = "$have" ]; then
            printf '  %-9s pinned %-8s up to date\n' "$1" "$have"
        else
            printf '  %-9s pinned %-8s latest %s\n' "$1" "$have" "$new"; outdated=1
        fi
    done
    if [ $outdated = 1 ]; then
        cat <<'EOF'

To move to a newer version:
  1. edit the *_V version and its *_SHA checksum in build.sh
     (get the checksum with: curl -fL <url> | shasum -a 256)
  2. ./build.sh && ./install.sh && ./test.sh
  3. update the version table in README.md and docs/HOW-IT-WORKS.md
New GCC major versions can add warnings/errors for old Arduino libraries; run test.sh.
EOF
    fi
}

case "${1:-}" in
    "") core_update ;;
    --check-toolchain) toolchain_check ;;
    --all) core_update; toolchain_check ;;
    -h|--help) sed -n '2,8p' "$0" ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 1 ;;
esac
