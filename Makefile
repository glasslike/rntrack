# Convenience Makefile for Debian 12 aarch64 RNTrack.
#
# Native aarch64 Debian 12:
#     make
#     sudo make install
#
# Cross from Debian 12 amd64 (or this Docker-based helper):
#     make CROSS_COMPILE=aarch64-linux-gnu- ARCH=aarch64
#     make docker          # recommended: bookworm toolchain + .deb

.PHONY: all install uninstall clean distclean docker deb check

LINUX_MAKE := $(MAKE) -C MakeFiles/linux

# Forward every Linux makefile knob the operator may set on the command line.
# CONFIG is the compile-time default config *file* (not a directory).
# Empty CONFIG is omitted so the upstream ~/fido/etc/rntrack.conf default stays.
MAKE_FWD := ARCH="$(or $(ARCH),$(shell uname -m))" \
	CROSS_COMPILE="$(CROSS_COMPILE)" \
	ENABLE_SCRIPTS="$(or $(ENABLE_SCRIPTS),0)" \
	ENABLE_LOG_PID="$(or $(ENABLE_LOG_PID),1)" \
	ENABLE_SYSLOG_LOG_FORMAT="$(or $(ENABLE_SYSLOG_LOG_FORMAT),0)" \
	PREFIX="$(or $(PREFIX),/usr)" \
	DEBUG="$(or $(DEBUG),0)"
ifdef CONFIG
MAKE_FWD += CONFIG="$(CONFIG)"
endif

all:
	$(LINUX_MAKE) all $(MAKE_FWD)

install:
	$(LINUX_MAKE) install PREFIX="$(or $(PREFIX),/usr)" DESTDIR="$(DESTDIR)"

uninstall:
	$(LINUX_MAKE) uninstall PREFIX="$(or $(PREFIX),/usr)" DESTDIR="$(DESTDIR)"

clean:
	$(LINUX_MAKE) clean
	rm -f tests/check_smapi_types

distclean:
	$(LINUX_MAKE) distclean
	rm -f tests/check_smapi_types
	rm -rf out debian/rntrack debian/.debhelper debian/files debian/*.substvars

# Type-size probe. Pass the same CROSS_COMPILE as `make all`.
check:
	$(or $(CROSS_COMPILE),)gcc -O2 -Wall -DUNIX -Ismapi/h \
		-o tests/check_smapi_types tests/check_smapi_types.c
	@if [ -n "$(CROSS_COMPILE)" ] && command -v qemu-aarch64-static >/dev/null 2>&1; then \
		qemu-aarch64-static -L /usr/aarch64-linux-gnu tests/check_smapi_types; \
	elif [ "$$(uname -m)" = aarch64 ]; then \
		./tests/check_smapi_types; \
	else \
		echo "Compiled tests/check_smapi_types; run it on aarch64 or via qemu."; \
	fi

deb: all
	./scripts/pack-deb.sh MakeFiles/linux/rntrack

docker:
	./scripts/build-debian12-aarch64.sh
