#!/bin/sh
# Compile test sketches with arduino-cli and check the native compiler was used.
#   ./test.sh [FQBN...]      # default: arduino:avr:nano arduino:avr:uno arduino:avr:mega
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
BOARDS=${*:-arduino:avr:nano arduino:avr:uno arduino:avr:mega}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
fail=0
for fqbn in $BOARDS; do
    for sk in "$HERE"/test/*/; do
        name=$(basename "$sk")
        dir="$OUT/$(echo "$fqbn" | tr : _)-$name"
        if arduino-cli compile --fqbn "$fqbn" --verbose --output-dir "$dir" "$sk" > "$dir.log" 2>&1; then
            if grep -q "Library/Arduino15/packages/arduino/tools/avr-gcc" "$dir.log"; then
                echo "FAIL $fqbn $name: compiled with Arduino's bundled avr-gcc (run ./install.sh)"; fail=1
            else
                size=$(grep -o "Sketch uses [0-9]* bytes" "$dir.log" | head -1)
                echo "ok   $fqbn $name: $size"
            fi
        else
            echo "FAIL $fqbn $name (log: see below)"; tail -20 "$dir.log"; fail=1
        fi
    done
done
gcc=$(grep -o "[^ \"]*/avr-g++" "$OUT"/*.log 2>/dev/null | head -1 || true)
[ -n "$gcc" ] && echo "compiler: $gcc ($(file -b "$gcc" | cut -d, -f1))"
exit $fail
