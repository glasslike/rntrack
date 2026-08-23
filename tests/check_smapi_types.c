/*
 * check_smapi_types.c - Fail the build if SMAPI on-disk types are wrong.
 *
 * RNTrack talks to JAM, Squish and FTS-0001 PKT files. Those formats store
 * 16- and 32-bit little-endian integers. On LP64 (x86_64, aarch64) a naive
 * "typedef unsigned long dword" makes dword 8 bytes and silently corrupts
 * message bases. This translation unit is compiled for the *target*
 * architecture (aarch64 for Debian 12 arm64) so a missed header patch
 * becomes a compile or runtime error instead of a bad binary.
 *
 * Copyright (c) 2026 RNTrack Debian 12 aarch64 packaging.
 * Licensed under GNU GPL version 2, same as RNTrack.
 */

#include "compiler.h"
#include "msgapi.h"
#include "api_jam.h"

#include <stdio.h>

/* Compile-time: dword must be exactly 32 bits, word exactly 16. */
typedef char assert_dword_is_32bit[sizeof(dword) == 4 ? 1 : -1];
typedef char assert_word_is_16bit[sizeof(word) == 2 ? 1 : -1];

/*
 * JAMHDRINFO is a 1024-byte on-disk header (4-byte signature + six 32-bit
 * fields + 996 reserved). If dword is 64-bit the struct grows and this
 * array type becomes illegal.
 */
typedef char assert_jamhdrinfo_is_1024[sizeof(JAMHDRINFO) == HDRINFO_SIZE ? 1 : -1];

int main(void)
{
    int failed = 0;

    printf("sizeof(dword)=%u (expect 4)\n", (unsigned)sizeof(dword));
    printf("sizeof(word)=%u (expect 2)\n", (unsigned)sizeof(word));
    printf("sizeof(JAMHDRINFO)=%u (expect %u)\n",
           (unsigned)sizeof(JAMHDRINFO), (unsigned)HDRINFO_SIZE);

#ifdef __LITTLE_ENDIAN__
    puts("__LITTLE_ENDIAN__ is defined");
#else
    puts("ERROR: __LITTLE_ENDIAN__ is NOT defined (PKT/JAM I/O will be wrong)");
    failed = 1;
#endif

#ifdef __AARCH64__
    puts("__AARCH64__ is defined");
#endif

#ifdef __FLAT__
    puts("__FLAT__ is defined");
#endif

    if (sizeof(dword) != 4 || sizeof(word) != 2 || sizeof(JAMHDRINFO) != HDRINFO_SIZE) {
        failed = 1;
    }

    return failed;
}
