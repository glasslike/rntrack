# Debian 12 / modern toolchain notes

This fork of [vasilyevmax/rntrack](https://github.com/vasilyevmax/rntrack)
builds RNTrack 2.3.1 on Debian 12 (bookworm), including aarch64. It also
fixes SMAPI type sizes on LP64 ARM (`dword` must stay 32-bit) and little-endian
detection. See `tests/check_smapi_types.c`.

Optional compile features used here:

* `ENABLE_SCRIPTS=1` — embedded Perl
* `ENABLE_LOG_PID=1` — PID in each log line
* `ENABLE_SYSLOG_LOG_FORMAT=1` — syslog-style timestamps
* `CONFIG=...` — compile-time default config file
* `PREFIX=...` — install prefix (`bin/` and `share/man/man1/`)

## Quick build (Debian 12)

```bash
sudo apt-get install -y g++ make gzip libperl-dev

cd ~/src
git clone https://github.com/glasslike/rntrack.git
cd rntrack

make -j"$(nproc)" ENABLE_SCRIPTS=1 ENABLE_LOG_PID=1 ENABLE_SYSLOG_LOG_FORMAT=1
sudo make install
rntrack -h
```

Default install is `/usr/bin/rntrack`. Default config is
`~/fido/etc/rntrack.conf` unless `CONFIG=` is set at build time.

## Extended build (FTN prefix under `/home/map/ftn`)

Same layout as the other FTN tools: binaries in `usr/bin`, config directory
`usr/etc/rntrack`.

```bash
sudo apt-get install -y g++ make gzip libperl-dev

mkdir -p ~/src
cd ~/src
git clone https://github.com/glasslike/rntrack.git
cd rntrack

make distclean

make -j"$(nproc)" \
  PREFIX=/home/map/ftn/usr \
  CONFIG=/home/map/ftn/usr/etc/rntrack/rntrack.conf \
  ENABLE_SCRIPTS=1 \
  ENABLE_LOG_PID=1 \
  ENABLE_SYSLOG_LOG_FORMAT=1

make install PREFIX=/home/map/ftn/usr
```

`make install` writes:

* `/home/map/ftn/usr/bin/rntrack`
* `/home/map/ftn/usr/share/man/man1/rntrack.1.gz`

Create the config directory and seed it from the samples (the makefile does
not install configs):

```bash
mkdir -p /home/map/ftn/usr/etc/rntrack/tpl
cp -a samples/rntrack.cfg /home/map/ftn/usr/etc/rntrack/rntrack.conf
cp -a samples/tpl/. /home/map/ftn/usr/etc/rntrack/tpl/
# optional charset tables and extra sample configs:
# cp -a samples/*.tbl samples/*.cfg /home/map/ftn/usr/etc/rntrack/
```

Edit `rntrack.conf` for your node (AKA, outbound, log path, ScanDir, and so
on). Paths inside the config must match your FTN tree.

Run:

```bash
/home/map/ftn/usr/bin/rntrack -h
/home/map/ftn/usr/bin/rntrack -c /home/map/ftn/usr/etc/rntrack/rntrack.conf
```

If `CONFIG=` was set at compile time, `-c` is optional.

Perl scripts: `ENABLE_SCRIPTS=1` embeds the interpreter. Put `.pl` files where
the config points (see `samples/perl-test.cfg` and `samples/test.pl`). Rebuild
with `make distclean` first if the previous binary was built without Perl.

## Cross-build from amd64

Do not use Ubuntu 24.04’s `g++-aarch64-linux-gnu` (glibc 2.38). Use Debian 12
bookworm’s toolchain, or:

```bash
./scripts/build-debian12-aarch64.sh
```

That image does **not** embed Perl (needs a native aarch64 `libperl`). For
Perl, build on the aarch64 Debian 12 box as above.

## Make options

| Option | Meaning |
| --- | --- |
| `PREFIX=/home/map/ftn/usr` | Install prefix |
| `CONFIG=/path/to/file` | Default config file compiled into the binary |
| `ENABLE_SCRIPTS=1` | Embedded Perl (`libperl-dev`) |
| `ENABLE_LOG_PID=1` | PID in log lines |
| `ENABLE_SYSLOG_LOG_FORMAT=1` | Syslog-style log timestamps |
| `DEBUG=1` | Debug build (`-Og`, no strip) |

`make uninstall PREFIX=...` removes the binary and man page.
