#!/bin/sh
# Point the Arduino AVR core (arduino:avr) at a native toolchain by writing a
# platform.local.txt next to its platform.txt. Works for arduino-cli and
# Arduino IDE 2, which share the same data directory.
#
#   ./install.sh [TOOLCHAIN_DIR]        # default: ~/.local/avr
#
# Re-run after `arduino-cli core upgrade` (each core version has its own dir).
set -eu

TC=${1:-$HOME/.local/avr}
TC=$(cd "$TC" 2>/dev/null && pwd) || { echo "error: toolchain dir not found: ${1:-$HOME/.local/avr}" >&2; exit 1; }
MARK="# managed by arduino-avr-arm64"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -x "$TC/bin/avr-gcc" ] || die "$TC/bin/avr-gcc not found (run ./build.sh or unpack a release first)"
"$TC/bin/avr-gcc" -dumpversion >/dev/null 2>&1 || die "$TC/bin/avr-gcc does not run on this machine"
command -v arduino-cli >/dev/null || die "arduino-cli not found (brew install arduino-cli)"

DATA=$(arduino-cli config get directories.data 2>/dev/null || true)
[ -n "$DATA" ] || DATA="$HOME/Library/Arduino15"
CORES=$(ls -d "$DATA"/packages/arduino/hardware/avr/*/ 2>/dev/null || true)
[ -n "$CORES" ] || die "arduino:avr core not installed (arduino-cli core install arduino:avr)"

# Native avrdude for uploads, if available (Homebrew: brew install avrdude)
AVRDUDE=$(command -v avrdude || true)
AVRCONF=""
if [ -n "$AVRDUDE" ]; then
    for c in "$(dirname "$AVRDUDE")/../etc/avrdude.conf" /opt/homebrew/etc/avrdude.conf /usr/local/etc/avrdude.conf; do
        [ -f "$c" ] && { AVRCONF=$(cd "$(dirname "$c")" && pwd)/avrdude.conf; break; }
    done
fi

for core in $CORES; do
    f="${core}platform.local.txt"
    if [ -f "$f" ] && ! grep -q "$MARK" "$f"; then
        cp "$f" "$f.bak"
        echo "backed up existing $f -> $f.bak"
    fi
    {
        echo "$MARK"
        echo "# toolchain: $TC ($("$TC/bin/avr-gcc" -dumpversion))"
        echo "compiler.path=$TC/bin/"
        if [ -n "$AVRDUDE" ] && [ -n "$AVRCONF" ]; then
            echo "tools.avrdude.cmd.path=$AVRDUDE"
            echo "tools.avrdude.config.path=$AVRCONF"
        fi
    } > "$f"
    echo "wrote $f"
done

echo
echo "compiler : $TC/bin/avr-gcc $("$TC/bin/avr-gcc" -dumpversion)"
if [ -n "$AVRDUDE" ] && [ -n "$AVRCONF" ]; then
    echo "uploader : $AVRDUDE ($AVRCONF)"
else
    echo "uploader : Arduino's bundled avrdude (x86_64). For native uploads: brew install avrdude && ./install.sh"
fi
echo "verify   : ./test.sh"
