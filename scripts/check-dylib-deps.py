#!/usr/bin/env python3
"""Fail if a Mach-O dylib links anything except system libraries.

LiveContainer dlopens the tweak directly. A load command for CydiaSubstrate,
ElleKit, or /var/jb aborts that dlopen before the tweak's constructor runs.
"""
import struct
import sys

LC_REQ_DYLD = 0x80000000
LOAD_COMMANDS = {
    0xC,  # LC_LOAD_DYLIB
    0x18 | LC_REQ_DYLD,  # LC_LOAD_WEAK_DYLIB
    0x1F | LC_REQ_DYLD,  # LC_REEXPORT_DYLIB
    0x23 | LC_REQ_DYLD,  # LC_LOAD_UPWARD_DYLIB
}
ALLOWED_PREFIXES = ("/usr/lib/", "/System/Library/")
BANNED = (
    "substrate",
    "ellekit",
    "substitute",
    "libhooker",
    "cydiasubstrate",
    "/var/jb",
    "@rpath",
    "@executable_path",
    "@loader_path",
)


def load_commands(path):
    data = open(path, "rb").read()
    if len(data) < 32:
        raise SystemExit(f"{path}: file is too small")
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != 0xFEEDFACF:
        raise SystemExit(f"{path}: expected a thin little-endian 64-bit Mach-O, got {magic:#x}")
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    deps = []
    ident = None
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, offset)
        if cmdsize < 8 or offset + cmdsize > len(data):
            raise SystemExit(f"{path}: truncated load command")
        if cmd == 0xD or cmd in LOAD_COMMANDS:
            name_off = struct.unpack_from("<I", data, offset + 8)[0]
            start = offset + name_off
            end = data.find(b"\x00", start, offset + cmdsize)
            name = data[start:end if end != -1 else offset + cmdsize].decode("utf-8", "replace")
            if cmd == 0xD:
                ident = name
            else:
                deps.append(name)
        offset += cmdsize
    return ident, deps


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: check-dylib-deps.py TikSpice.dylib")
    ident, deps = load_commands(sys.argv[1])
    print(f"id: {ident}")
    if not deps:
        raise SystemExit("dylib has no load commands; that is unexpected")
    for dep in deps:
        print(f"load: {dep}")
        low = dep.lower()
        if any(token in low for token in BANNED) or not dep.startswith(ALLOWED_PREFIXES):
            raise SystemExit(f"unmet or non-system dependency: {dep}")
    print("ok: system libraries only")


if __name__ == "__main__":
    main()
