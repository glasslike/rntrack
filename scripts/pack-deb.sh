#!/bin/sh
# pack-deb.sh - Assemble a Debian arm64 .deb from a finished RNTrack binary.
#
# The binary must already be an ELF aarch64 executable linked against
# Debian 12's glibc (2.36). This script does not compile anything; it
# only lays out the package tree and runs dpkg-deb.
#
# Usage:
#   ./scripts/pack-deb.sh [path-to-rntrack-binary]
#
# Output:
#   out/rntrack_2.3.1-1~deb12+arm64_arm64.deb

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
VERSION="2.3.1-1~deb12+arm64"
BINARY="${1:-$ROOT/MakeFiles/linux/rntrack}"
OUTDIR="$ROOT/out"
PKG="$OUTDIR/pkg"

if [ ! -f "$BINARY" ]; then
    echo "error: binary not found: $BINARY" >&2
    echo "Build it first (see README.md)." >&2
    exit 1
fi

# Refuse to package a non-aarch64 binary: a host-arch accident is too easy
# when CROSS_COMPILE is forgotten.
arch_ok=0
if command -v file >/dev/null 2>&1; then
    FILE_OUT="$(file -b "$BINARY" 2>/dev/null || true)"
    case "$FILE_OUT" in
        *aarch64*|*ARM\ aarch64*) arch_ok=1 ;;
    esac
fi
if [ "$arch_ok" -eq 0 ] && command -v readelf >/dev/null 2>&1; then
    if readelf -h "$BINARY" 2>/dev/null | grep -q 'AArch64'; then
        arch_ok=1
        FILE_OUT="ELF AArch64 (readelf)"
    fi
fi
if [ "$arch_ok" -eq 0 ]; then
    echo "error: $BINARY is not an aarch64 ELF (file says: ${FILE_OUT:-unknown})" >&2
    exit 1
fi

rm -rf "$PKG"
mkdir -p "$PKG/usr/bin" \
         "$PKG/usr/share/man/man1" \
         "$PKG/usr/share/doc/rntrack/examples" \
         "$PKG/DEBIAN"

install -m 0755 "$BINARY" "$PKG/usr/bin/rntrack"

# Man page is gzipped by the upstream linux Makefile as a build side effect.
if [ -f "$ROOT/doc/rntrack.1.gz" ]; then
    install -m 0644 "$ROOT/doc/rntrack.1.gz" "$PKG/usr/share/man/man1/rntrack.1.gz"
elif [ -f "$ROOT/doc/rntrack.1" ]; then
    gzip -9c "$ROOT/doc/rntrack.1" > "$PKG/usr/share/man/man1/rntrack.1.gz"
fi

install -m 0644 "$ROOT/README.md" "$PKG/usr/share/doc/rntrack/README.md"
install -m 0644 "$ROOT/COPYING"   "$PKG/usr/share/doc/rntrack/copyright"
install -m 0644 "$ROOT/ChangeLog" "$PKG/usr/share/doc/rntrack/changelog"
gzip -9n -f "$PKG/usr/share/doc/rntrack/changelog" || true

# Sample configs: operators usually copy these under ~/fido/etc/.
if [ -d "$ROOT/samples" ]; then
    cp -a "$ROOT/samples/." "$PKG/usr/share/doc/rntrack/examples/"
fi

# Installed-Size is kilobytes, as required by Debian Policy.
INSTALLED_SIZE="$(du -sk "$PKG" | awk '{print $1}')"

# No Perl embedding in the default binary, so the runtime Depends stay small.
# libc6 2.36 is Debian 12's glibc; do not raise this without rebuilding
# against a newer bookworm (or later) toolchain.
cat > "$PKG/DEBIAN/control" << EOF
Package: rntrack
Version: $VERSION
Architecture: arm64
Maintainer: Alexey Matrosov <a.matrosoff@gmail.com>
Installed-Size: $INSTALLED_SIZE
Depends: libc6 (>= 2.36), libgcc-s1, libstdc++6
Section: comm
Priority: optional
Homepage: https://github.com/vasilyevmax/rntrack
Description: FTN netmail tracker (Fidonet Technology Networks)
 RNTrack parses Fidonet PKT files and message bases (OPUS *.msg, JAM,
 Squish), matches messages against patterns, and runs configured actions.
 Built for Debian 12 (bookworm) aarch64 with SMAPI LP64 type-size fixes.
EOF

mkdir -p "$OUTDIR"
DEB="$OUTDIR/rntrack_${VERSION}_arm64.deb"
dpkg-deb --build --root-owner-group "$PKG" "$DEB"
echo "Wrote $DEB"
file "$DEB"
