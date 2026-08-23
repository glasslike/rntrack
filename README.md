RNTrack for Debian 12 aarch64
=============================

This tree is [RNTrack 2.3.1](https://github.com/vasilyevmax/rntrack) plus the
fixes and packaging needed to build a working binary on **Debian 12
(bookworm), architecture arm64 / aarch64**.

RNTrack is a Fidonet netmail tracker: it reads PKT files or message bases
(OPUS `*.msg`, JAM, Squish), matches messages against patterns, and runs
the configured action. Upstream documentation lives in `doc/` and sample
configs in `samples/`.

Debian 12 does not ship an `rntrack` package. Build it from this source.


Why a special aarch64 build
---------------------------

Upstream SMAPI (the bundled message-base library) treated aarch64 like a
32-bit Unix host:

* `dword` became `unsigned long` (8 bytes on LP64 ARM). JAM and Squish
  on-disk headers expect 32-bit fields, so bases would be misread/miswritten.
* `__LITTLE_ENDIAN__` was never set (GCC defines `__aarch64__`, not
  `__arm__` / `__ARMEL__`), so the little-endian fast path was skipped.

This tree defines `__AARCH64__`, keeps `dword` 32-bit, and marks the
platform little-endian. `tests/check_smapi_types.c` fails the build if
those sizes regress.

The Linux makefile also defaults `ARCH` to `uname -m` (instead of always
`x86_64`) and accepts `CROSS_COMPILE=aarch64-linux-gnu-`.


Build on a Debian 12 aarch64 machine (native)
---------------------------------------------

This is the path you want on a Raspberry Pi 4/5, an ARM VPS, or any
bookworm arm64 box.

```sh
sudo apt update
sudo apt install --no-install-recommends g++ make gzip

make
sudo make install
rntrack -h
```

The binary goes to `/usr/bin/rntrack`, the man page to
`/usr/share/man/man1/rntrack.1.gz`. The default config path is
`~/fido/etc/rntrack.conf` (override with `CONFIG=/path/to/file` at build
time, or pass `-c` at run time). Copy a starting config from
`samples/rntrack.cfg`.

Optional Perl scripting (embedded interpreter):

```sh
sudo apt install libperl-dev
make ENABLE_SCRIPTS=1 ENABLE_LOG_PID=1
sudo make install
```

Uninstall:

```sh
sudo make uninstall
```


Cross-build from amd64: use Debian 12's toolchain, not Ubuntu's
---------------------------------------------------------------

A binary compiled on Ubuntu 24.04 with `g++-aarch64-linux-gnu` requests
`GLIBC_2.38` and **will not start** on Debian 12 (glibc 2.36). Always
compile with bookworm's compiler.

### Docker (recommended from any amd64 host)

Install Docker, then:

```sh
./scripts/build-debian12-aarch64.sh
```

That builds `debian:bookworm`, cross-compiles with
`aarch64-linux-gnu-g++`, runs the type-size probe under qemu, and writes:

* `out/rntrack` — ELF aarch64 executable
* `out/rntrack_2.3.1-1~deb12+arm64_arm64.deb` — installable package

On the Debian 12 aarch64 machine:

```sh
sudo apt install ./rntrack_2.3.1-1~deb12+arm64_arm64.deb
```

Equivalent manual Docker invocation:

```sh
docker build -t rntrack-debian12-arm64 .
cid=$(docker create rntrack-debian12-arm64)
mkdir -p out
docker cp "$cid:/out/." out/
docker rm "$cid"
```

### Without Docker, on Debian 12 amd64

```sh
sudo dpkg --add-architecture arm64
sudo apt update
sudo apt install g++-aarch64-linux-gnu make gzip qemu-user-static

make CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64
make check CROSS_COMPILE=aarch64-linux-gnu-
./scripts/pack-deb.sh MakeFiles/linux/rntrack
```

### `dpkg-buildpackage` on Debian 12

On native arm64:

```sh
sudo apt install build-essential debhelper
dpkg-buildpackage -us -uc -b
```

On amd64, the same command uses `g++-aarch64-linux-gnu` (see
`debian/control` Build-Depends) because `Architecture: arm64`.


Make options (Linux)
--------------------

Run from the repo root (`make`) or from `MakeFiles/linux`.

| Option | Meaning |
| --- | --- |
| `PREFIX=/usr/local` | Install prefix (default `/usr`) |
| `CONFIG=/path/to/cfg` | Compile-time default config path |
| `ENABLE_SCRIPTS=1` | Embed Perl (needs `libperl-dev` on the *target*) |
| `ENABLE_LOG_PID=1` | Include the PID in log lines (on by default in this tree's wrapper Makefile) |
| `ENABLE_SYSLOG_LOG_FORMAT=1` | Syslog-style timestamps |
| `CROSS_COMPILE=aarch64-linux-gnu-` | Cross toolchain prefix (trailing `-` required) |
| `ARCH=aarch64` | Target architecture (default: `uname -m`) |
| `DEBUG=1` | Debug build (`-Og`, no strip) |
| `STATIC=1` | Static musl link (implies `USE_MUSL=1`) |

`sudo make install` / `sudo make uninstall` as in upstream `INSTALL`.


Runtime
-------

```sh
rntrack -h
rntrack -c ~/fido/etc/rntrack.conf
```

Sample configs and templates: `samples/` (also
`/usr/share/doc/rntrack/examples/` after installing the `.deb`). Full
language documentation: `doc/FAQ_en`, `doc/FAQ_ru`, `doc/rntrack.1`.


License
-------

RNTrack is GNU GPL version 2 (see `COPYING`). Bundled SMAPI is LGPL.
Authors: `AUTHORS`. Bug reports: `BUG-REPORTING`.
