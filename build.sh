#!/bin/sh
# Build a native AVR toolchain (binutils + gcc + avr-libc) for Apple Silicon
# from official sources, for use with arduino-cli / Arduino IDE 2.
#
#   ./build.sh                         # installs into ~/.local/avr
#   PREFIX=/opt/avr JOBS=4 ./build.sh
#
# gmp/mpfr/mpc/isl are built in-tree (static), so the result only depends on
# macOS system libraries and can be packaged and copied to other Macs.
set -eu

BINUTILS_V=2.43
GCC_V=14.2.0
LIBC_V=2.2.1

# sha256 of the source archives this repo was tested with
BINUTILS_SHA=b53606f443ac8f01d1d5fc9c39497f2af322d99e14cea5c0b4b124d630379365
GCC_SHA=a7b39bc69cbf9e25826c5a60ab26477001f7c08d85cec04bc0e29cabed6f3cc9
LIBC_SHA=006a6306cbbc938c3bdb583ac54f93fe7d7c8cf97f9cde91f91c6fb0273ab465

HERE=$(cd "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-$HOME/.local/avr}
BUILD=${BUILD:-$HERE/.build}
JOBS=${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for t in cc c++ make curl tar shasum; do
    command -v $t >/dev/null || die "missing '$t' (install the Xcode Command Line Tools: xcode-select --install)"
done

fetch() { # url file sha256
    if [ ! -s "$2" ]; then
        say "downloading $2"
        curl -fL --retry 3 -o "$2.part" "$1"
        mv "$2.part" "$2"
    fi
    echo "$3  $2" | shasum -a 256 -c - >/dev/null || die "checksum mismatch for $2 (delete it and retry)"
}

mkdir -p "$BUILD" "$PREFIX"
cd "$BUILD"

fetch "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_V.tar.xz" "binutils-$BINUTILS_V.tar.xz" $BINUTILS_SHA
fetch "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_V/gcc-$GCC_V.tar.xz" "gcc-$GCC_V.tar.xz" $GCC_SHA
fetch "https://github.com/avrdudes/avr-libc/releases/download/avr-libc-$(echo $LIBC_V | tr . _)-release/avr-libc-$LIBC_V.tar.bz2" \
      "avr-libc-$LIBC_V.tar.bz2" $LIBC_SHA

for f in binutils-$BINUTILS_V.tar.xz gcc-$GCC_V.tar.xz avr-libc-$LIBC_V.tar.bz2; do
    d=${f%.tar.*}
    [ -d "$d" ] || { say "extracting $f"; tar xf "$f"; }
done

if [ ! -e gcc-$GCC_V/gmp ]; then
    say "fetching gmp/mpfr/mpc/isl (gcc.gnu.org, checksums verified by GCC's script)"
    (cd gcc-$GCC_V && ./contrib/download_prerequisites)
fi

export PATH="$PREFIX/bin:$PATH"
# MAKEINFO=true: skip the info manuals (needs texinfo, not useful here)
MK="make -j$JOBS MAKEINFO=true"

say "binutils $BINUTILS_V"
rm -rf build-binutils && mkdir build-binutils && cd build-binutils
../binutils-$BINUTILS_V/configure --prefix="$PREFIX" --target=avr \
    --disable-nls --disable-werror --with-system-zlib \
    --disable-gdb --disable-gdbserver --disable-sim --disable-gprofng \
    --disable-libdecnumber --disable-readline
$MK
$MK install
cd ..

say "gcc $GCC_V (C, C++, LTO)"
rm -rf build-gcc && mkdir build-gcc && cd build-gcc
../gcc-$GCC_V/configure --prefix="$PREFIX" --target=avr \
    --enable-languages=c,c++ --enable-lto --disable-nls --with-system-zlib \
    --disable-libssp --disable-libcc1 --disable-shared --disable-threads \
    --with-dwarf2 --with-avrlibc
$MK all-gcc all-target-libgcc
$MK install-gcc install-target-libgcc
cd ..

say "avr-libc $LIBC_V"
cd avr-libc-$LIBC_V
./configure --prefix="$PREFIX" --build="$(./config.guess)" --host=avr
$MK
$MK install
cd ..

say "done"
"$PREFIX/bin/avr-gcc" --version | head -1
file "$PREFIX/bin/avr-gcc"
echo "next: ./install.sh $PREFIX"
