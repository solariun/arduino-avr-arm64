# arduino-avr-arm64

A **native Apple Silicon (arm64) AVR toolchain** for Arduino. It provides avr-gcc 14.2, binutils 2.43 and avr-libc 2.2.1, and is set up to work with `arduino-cli` and Arduino IDE 2 **without Rosetta**.

## Why

The `arduino:avr` core (Uno, Nano, Mega, …) downloads avr-gcc 7.3.0 and avrdude, and on macOS both are **x86_64-only binaries**. On an M-series Mac, compiling fails with this error unless Rosetta 2 is installed:

```
fork/exec …/avr-g++: bad CPU type in executable
```

This repo builds the same toolchain natively from the official GNU and avr-libc sources. It then points the Arduino AVR core at it with Arduino's own override mechanism, `platform.local.txt`. Arduino keeps managing the core, the libraries and the board definitions. Only the compiler is swapped.

## Quick start: prebuilt release

You don't need to build anything. Download the toolchain from [Releases](https://github.com/solariun/arduino-avr-arm64/releases):

```bash
brew install arduino-cli && arduino-cli core install arduino:avr
B=https://github.com/solariun/arduino-avr-arm64/releases/download/v14.2.0-1
curl -fLO $B/avr-gcc-14.2.0-darwin-arm64.tar.xz
curl -fLO $B/avr-gcc-14.2.0-darwin-arm64.tar.xz.sha256
shasum -a 256 -c avr-gcc-14.2.0-darwin-arm64.tar.xz.sha256
mkdir -p ~/.local && tar -C ~/.local -xJf avr-gcc-14.2.0-darwin-arm64.tar.xz
git clone https://github.com/solariun/arduino-avr-arm64 && cd arduino-avr-arm64
./install.sh ~/.local/avr-gcc-14.2.0-darwin-arm64
./test.sh
```

## Quick start: build from source

```bash
# 0. prerequisites: Xcode Command Line Tools, arduino-cli and the AVR core
xcode-select --install                  # if not installed yet
brew install arduino-cli
arduino-cli core install arduino:avr

# 1. build the toolchain into ~/.local/avr (about 20 min, ~3 GB of temporary space)
./build.sh

# 2. tell the Arduino AVR core to use it
./install.sh

# 3. check it
./test.sh
```

After that, compiling works as usual, with no extra flags:

```bash
arduino-cli compile --fqbn arduino:avr:nano MySketch/
```

Arduino IDE 2 picks it up too, because it shares the same `~/Library/Arduino15` directory.

### Uploading to a board

Arduino's bundled `avrdude` is also x86_64. Install the native one from Homebrew **before** running `install.sh`, and uploads will use it:

```bash
brew install avrdude
./install.sh
arduino-cli upload -p /dev/cu.usbserial-XXXX --fqbn arduino:avr:nano MySketch/
```

## Scripts

| Script | What it does |
|---|---|
| `build.sh` | Downloads the pinned sources and verifies their SHA-256, then builds binutils, gcc (C, C++, LTO) and avr-libc into `$PREFIX` (default `~/.local/avr`). |
| `install.sh [dir]` | Writes `platform.local.txt` into every installed `arduino:avr` core version. If a `platform.local.txt` already exists, it is backed up first. |
| `uninstall.sh` | Removes those files and restores any backups. Arduino goes back to its bundled toolchain. |
| `test.sh [fqbn…]` | Compiles the sketches in `test/` for Nano, Uno and Mega, and fails if Arduino's bundled compiler was used. |
| `update.sh` | Updates `arduino:avr` from Arduino's official package index, re-applies `platform.local.txt` and runs the tests. `--check-toolchain` compares the pinned binutils, gcc and avr-libc versions with the latest upstream releases. `--all` does both. |
| `package.sh [dir]` | Creates `dist/avr-gcc-<ver>-darwin-arm64.tar.xz` plus a `.sha256` file. It refuses to package binaries that depend on non-system libraries. |

Build options are set with environment variables: `PREFIX` (install directory), `JOBS` (parallel jobs) and `BUILD` (scratch directory, default `./.build`).

## Using a prebuilt tarball

You can build once and copy the result to other Macs. The toolchain is relocatable and only links against macOS system libraries.

```bash
./package.sh                                   # on the build machine
# on the other Mac:
mkdir -p ~/.local && tar -C ~/.local -xJf avr-gcc-14.2.0-darwin-arm64.tar.xz
xattr -dr com.apple.quarantine ~/.local/avr-gcc-14.2.0-darwin-arm64   # if it was downloaded through a browser
./install.sh ~/.local/avr-gcc-14.2.0-darwin-arm64
```

## Updating the Arduino core

Each core version lives in its own folder, for example `…/hardware/avr/1.8.8/`. Use `./update.sh` to upgrade the core. It re-applies `platform.local.txt` to the new version for you. If you run `arduino-cli core upgrade` yourself, run `./install.sh` again afterwards.

## How it works

See [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) for:
- the `platform.local.txt` mechanism
- which properties are overridden
- the build flags and why each is there
- the differences from Arduino's GCC 7.3
- troubleshooting.

## License

The scripts and docs in this repo are MIT-licensed. The toolchain they build is GCC and binutils (GPLv3 with the GCC Runtime Library Exception) and avr-libc (modified BSD).
