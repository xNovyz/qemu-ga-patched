#!/usr/bin/env bash
# Cross-builds qemu-ga.exe (Windows x86_64) from the qemu submodule using mingw-w64.
#
# Required packages (Arch):
#   paru -S --needed mingw-w64-gcc mingw-w64-glib2 mingw-w64-pkg-config
# Optional, for the .msi installer (adds --enable-guest-agent-msi):
#   paru -S --needed msitools
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v x86_64-w64-mingw32-gcc >/dev/null; then
    echo "ERROR: mingw-w64 toolchain not found. Install with:" >&2
    echo "  paru -S --needed mingw-w64-gcc mingw-w64-glib2 mingw-w64-pkg-config" >&2
    exit 1
fi

git submodule update --init --depth 1 qemu

# Apply patches (idempotent: skips patches that are already applied)
for p in patches/*.patch; do
    pa="$(realpath "$p")"
    if git -C qemu apply --check "$pa" 2>/dev/null; then
        echo "Applying $p"
        git -C qemu apply "$pa"
    elif git -C qemu apply --check -R "$pa" 2>/dev/null; then
        echo "Already applied: $p"
    else
        echo "ERROR: $p does not apply cleanly" >&2
        exit 1
    fi
done

# Point pkg-config at the mingw sysroot .pc files (glib-2.0 for Windows)
export PKG_CONFIG_LIBDIR=/usr/x86_64-w64-mingw32/lib/pkgconfig
export PKG_CONFIG_PATH=/usr/x86_64-w64-mingw32/share/pkgconfig

mkdir -p qemu/build-win
cd qemu/build-win
if [ ! -f build.ninja ]; then
    ../configure --cross-prefix=x86_64-w64-mingw32- \
        --target-list="" \
        --enable-guest-agent \
        --disable-werror
fi
make -j"$(nproc)" qemu-ga.exe
echo "Built: $(pwd)/qga/qemu-ga.exe"
echo "Note: qemu-ga.exe needs the mingw glib DLLs at runtime (e.g. libglib-2.0-0.dll"
echo "from /usr/x86_64-w64-mingw32/bin) unless you ship them alongside the exe."
