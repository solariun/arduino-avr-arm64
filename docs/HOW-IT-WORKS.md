# How it works

## 1. Where Arduino gets its compiler

Arduino's AVR core is installed under `~/Library/Arduino15/packages/arduino/hardware/avr/<version>/`. Its `platform.txt` defines every build command in terms of properties:

```properties
compiler.path={runtime.tools.avr-gcc.path}/bin/
compiler.c.cmd=avr-gcc
compiler.cpp.cmd=avr-g++
compiler.ar.cmd=avr-gcc-ar
compiler.objcopy.cmd=avr-objcopy
compiler.elf2hex.cmd=avr-objcopy
compiler.size.cmd=avr-size
...
tools.avrdude.cmd.path={path}/bin/avrdude
tools.avrdude.config.path={path}/etc/avrdude.conf
```

`{runtime.tools.avr-gcc.path}` resolves to the tool Arduino downloaded, `…/packages/arduino/tools/avr-gcc/7.3.0-atmel3.6.1-arduino7/`. On macOS that is an x86_64 build.

## 2. The override: `platform.local.txt`

The [Arduino platform specification](https://arduino.github.io/arduino-cli/latest/platform-specification/#platformlocaltxt) lets you put a `platform.local.txt` next to `platform.txt`. Any property defined there **overrides** the one in `platform.txt`. arduino-cli and Arduino IDE 2 both honor it.

`install.sh` writes:

```properties
# managed by arduino-avr-arm64
compiler.path=/Users/you/.local/avr/bin/
tools.avrdude.cmd.path=/opt/homebrew/bin/avrdude          # only if a native avrdude is installed
tools.avrdude.config.path=/opt/homebrew/etc/avrdude.conf
```

The native toolchain uses the same executable names as Arduino's, such as `avr-gcc`, `avr-g++`, `avr-gcc-ar`, `avr-objcopy` and `avr-size`. So changing `compiler.path` is enough: every compile, link, archive, objcopy and size step runs natively. Arduino's x86_64 tool stays installed but is never executed.

Nothing else changes:
- board definitions (`boards.txt`)
- the Arduino core sources
- bundled libraries such as Wire, SPI, EEPROM and SoftwareSerial
- the bootloaders
- library management.

## 3. The build (`build.sh`)

| Component | Version | Source |
|---|---|---|
| binutils | 2.43 | ftp.gnu.org |
| gcc | 14.2.0 | ftp.gnu.org |
| avr-libc | 2.2.1 | github.com/avrdudes/avr-libc (the official project) |
| gmp, mpfr, mpc, isl | GCC's pinned versions | gcc.gnu.org infrastructure, via `contrib/download_prerequisites` |

The three main archives are checked against SHA-256 hashes stored in the script. GCC's own script verifies its prerequisites with SHA-512.

Configure flags that matter:

| Flag | Why |
|---|---|
| `--target=avr` | Cross-compiler for AVR. The host is detected as `aarch64-apple-darwin`. |
| `--with-system-zlib` | The zlib bundled with binutils and gcc no longer compiles against recent macOS SDKs (its `fdopen` macro clashes with `<stdio.h>`). macOS ships zlib anyway. |
| `--enable-languages=c,c++` | The Arduino core is C++. |
| `--enable-lto` | Arduino builds with `-flto -fuse-linker-plugin` and archives with `avr-gcc-ar`. |
| `--with-avrlibc` | Tells GCC the C library is avr-libc. This affects the startup code and the default linker libraries. |
| `--disable-shared --disable-threads --disable-libssp --disable-libcc1` | Not applicable to bare-metal AVR. |
| `MAKEINFO=true` (make variable) | Skips the texinfo manuals, so `texinfo` isn't required. |
| in-tree gmp/mpfr/mpc/isl | They are linked statically, so the toolchain depends only on `/usr/lib` system libraries. This makes it relocatable and lets it be packaged. |

GCC only builds `libgcc` for the target (`all-gcc all-target-libgcc`). AVR has no libstdc++; the Arduino core brings its own `new`/`delete`.

## 4. Differences from Arduino's GCC 7.3

- **Newer warnings.** GCC 14 warns about some things 7.3 accepted silently. Arduino uses `-w` or `-Wall` depending on your *compiler warnings* setting, so builds still succeed. With "All" warnings you may see new messages from third-party libraries.
- **Code size.** It is usually similar, sometimes a little smaller or larger. Compare with `arduino-cli compile` output ("Sketch uses N bytes").
- **`-fpermissive` cases.** A few very old libraries relied on code GCC 14 now rejects as an error, for example implicit function declarations in C files. Fix the library, or add `compiler.c.extra_flags=-Wno-error=implicit-function-declaration` to `platform.local.txt`.
- **Newer devices.** avr-libc 2.2 supports newer chips, but the `arduino:avr` board list is unchanged.

## 5. Troubleshooting

| Symptom | Fix |
|---|---|
| `bad CPU type in executable` (compile) | `platform.local.txt` is missing for this core version. Run `./install.sh` and check with `./test.sh`. |
| `bad CPU type` during **upload** | Arduino's avrdude is being used. Run `brew install avrdude && ./install.sh`. |
| `test.sh` says "compiled with Arduino's bundled avr-gcc" | A cached build may be in use. Run `arduino-cli cache clean`, then run `./install.sh` again. |
| macOS says the binary "cannot be opened" | The tarball came through a browser. Run `xattr -dr com.apple.quarantine <dir>`. |
| Build fails in zlib or with `fdopen` errors | You are using an old copy of `build.sh` without `--with-system-zlib`. |
| Build fails with `makeinfo: command not found` | Use `MAKEINFO=true`, which `build.sh` already passes. |
| Want to go back to stock Arduino | Run `./uninstall.sh`. |

To see exactly which compiler is used, run:

```bash
arduino-cli compile --fqbn arduino:avr:nano --verbose MySketch/ | grep avr-g++
```
