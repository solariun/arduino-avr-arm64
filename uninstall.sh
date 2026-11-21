#!/bin/sh
# Remove the platform.local.txt files written by install.sh (restoring backups).
set -eu
MARK="# managed by arduino-avr-arm64"
DATA=$(arduino-cli config get directories.data 2>/dev/null || true)
[ -n "$DATA" ] || DATA="$HOME/Library/Arduino15"
for core in "$DATA"/packages/arduino/hardware/avr/*/; do
    f="${core}platform.local.txt"
    [ -f "$f" ] && grep -q "$MARK" "$f" || continue
    rm "$f"
    echo "removed $f"
    if [ -f "$f.bak" ]; then mv "$f.bak" "$f"; echo "restored $f"; fi
done
echo "arduino:avr is back to Arduino's bundled toolchain."
