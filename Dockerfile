# Dockerfile for a Debian 12 (bookworm) aarch64 RNTrack binary.
#
# The image itself may run on amd64: we install bookworm's
# aarch64-linux-gnu cross compiler so the result links against glibc 2.36
# (Debian 12), not the host distro's newer libc.
#
# Build:  docker build -t rntrack-debian12-arm64 .
# Artifacts are left in /out inside the image.

FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# qemu-user-static is only used to smoke-test the aarch64 binary on amd64.
# file/binutils confirm ELF class and architecture before we pack the .deb.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        make \
        gcc \
        g++ \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        gzip \
        file \
        binutils \
        qemu-user-static \
        dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . /build

# CROSS_COMPILE must end with '-'. ARCH=aarch64 is recorded for musl
# triplets; with glibc it mainly documents the target and skips i686 -march.
RUN make -C MakeFiles/linux -j"$(nproc)" \
        ARCH=aarch64 \
        CROSS_COMPILE=aarch64-linux-gnu- \
        PREFIX=/usr \
        ENABLE_LOG_PID=1 \
    && aarch64-linux-gnu-gcc -O2 -Wall -DUNIX -Ismapi/h \
        -o tests/check_smapi_types tests/check_smapi_types.c \
    && qemu-aarch64-static -L /usr/aarch64-linux-gnu tests/check_smapi_types \
    && qemu-aarch64-static -L /usr/aarch64-linux-gnu MakeFiles/linux/rntrack -h \
    && file MakeFiles/linux/rntrack \
    && aarch64-linux-gnu-readelf -A MakeFiles/linux/rntrack | head

# Stage installable files into /out for `docker cp`.
RUN mkdir -p /out \
    && cp -a MakeFiles/linux/rntrack /out/rntrack \
    && chmod +x /build/scripts/pack-deb.sh \
    && /build/scripts/pack-deb.sh /out/rntrack \
    && cp -a /build/out/*.deb /out/

# Default command: print the packaged binary identity.
CMD ["file", "/out/rntrack"]
