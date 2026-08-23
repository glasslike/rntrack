#!/bin/sh
# build-debian12-aarch64.sh - Produce an RNTrack binary for Debian 12 arm64.
#
# Preferred path: compile inside a debian:bookworm container with the
# aarch64-linux-gnu cross toolchain. That links against glibc 2.36, which
# is what Debian 12 actually ships. Compiling on Ubuntu 24.04 (glibc 2.39)
# yields a binary that will not start on bookworm (GLIBC_2.38 symbols).
#
# Native path: if this script is already running on Debian 12 aarch64,
# it builds with the host g++ and skips Docker.
#
# Usage:
#   ./scripts/build-debian12-aarch64.sh
#   ENABLE_SCRIPTS=1 ./scripts/build-debian12-aarch64.sh   # native aarch64 only
#
# Artifacts:
#   out/rntrack
#   out/rntrack_2.3.1-1~deb12+arm64_arm64.deb

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENABLE_SCRIPTS="${ENABLE_SCRIPTS:-0}"
IMAGE_NAME="${RNTRACK_DOCKER_IMAGE:-rntrack-debian12-arm64}"

# Return 0 when /etc/os-release looks like Debian 12 on aarch64.
is_native_bookworm_arm64() {
    [ "$(uname -m)" = aarch64 ] || return 1
    [ -f /etc/os-release ] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = debian ] || return 1
    [ "${VERSION_ID:-}" = "12" ] || return 1
    return 0
}

build_native() {
    echo "==> Native Debian 12 aarch64 build"
    # g++, make, gzip are enough; libperl-dev is only for ENABLE_SCRIPTS=1.
    command -v g++ >/dev/null || {
        echo "Install build tools: sudo apt install g++ make gzip" >&2
        exit 1
    }
    make -C MakeFiles/linux -j"$(nproc)" \
        ARCH=aarch64 \
        PREFIX=/usr \
        ENABLE_LOG_PID=1 \
        ENABLE_SCRIPTS="$ENABLE_SCRIPTS"
    gcc -O2 -Wall -DUNIX -Ismapi/h -o tests/check_smapi_types tests/check_smapi_types.c
    ./tests/check_smapi_types
    ./MakeFiles/linux/rntrack -h >/dev/null
    mkdir -p "$ROOT/out"
    cp -a MakeFiles/linux/rntrack "$ROOT/out/rntrack"
    "$ROOT/scripts/pack-deb.sh" "$ROOT/out/rntrack"
}

build_docker() {
    if [ "$ENABLE_SCRIPTS" = 1 ]; then
        echo "warning: ENABLE_SCRIPTS=1 is ignored for the Docker cross build" >&2
        echo "         (Perl embedding needs a native aarch64 libperl)." >&2
    fi

    DOCKER="docker"
    if ! docker info >/dev/null 2>&1; then
        if command -v sudo >/dev/null && sudo docker info >/dev/null 2>&1; then
            DOCKER="sudo docker"
        else
            echo "error: Docker daemon is not reachable. Start it or build on Debian 12 aarch64." >&2
            exit 1
        fi
    fi

    echo "==> Docker build on debian:bookworm (aarch64-linux-gnu cross toolchain)"
    $DOCKER build -t "$IMAGE_NAME" -f "$ROOT/Dockerfile" "$ROOT"

    mkdir -p "$ROOT/out"
    # Copy artifacts out of the image without leaving a dangling container.
    CID="$($DOCKER create "$IMAGE_NAME")"
    $DOCKER cp "$CID:/out/rntrack" "$ROOT/out/rntrack"
    $DOCKER cp "$CID:/out/rntrack_2.3.1-1~deb12+arm64_arm64.deb" \
        "$ROOT/out/rntrack_2.3.1-1~deb12+arm64_arm64.deb" || true
    $DOCKER rm "$CID" >/dev/null
    echo "==> Artifacts in $ROOT/out/"
    ls -l "$ROOT/out"
    file "$ROOT/out/rntrack"
}

if is_native_bookworm_arm64; then
    build_native
else
    build_docker
fi
