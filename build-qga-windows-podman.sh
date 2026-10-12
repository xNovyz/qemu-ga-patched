#!/usr/bin/env bash
# Builds qemu-ga.exe for Windows inside a Fedora podman container.
# No host mingw toolchain needed; Fedora ships prebuilt mingw64 packages.
# Output: dist/qemu-ga-<ver>-windows-x86_64/ (qemu-ga.exe + required DLLs)
set -euo pipefail
cd "$(dirname "$0")"
SRC="$(pwd)"

podman run --rm -v "$SRC:/src:Z" -w /src fedora:latest bash -s <<'EOS'
set -euo pipefail
dnf install -y -q mingw64-gcc mingw64-glib2 meson ninja-build git python3 perl make glib2-devel diffutils

# qemu configure uses ${cross_prefix}pkg-config; provide a sysroot wrapper if missing
if ! command -v x86_64-w64-mingw32-pkg-config >/dev/null; then
    cat > /usr/local/bin/x86_64-w64-mingw32-pkg-config <<'EOF'
#!/bin/sh
export PKG_CONFIG_LIBDIR=/usr/x86_64-w64-mingw32/sys-root/mingw/lib/pkgconfig:/usr/x86_64-w64-mingw32/sys-root/mingw/share/pkgconfig
exec /usr/bin/pkg-config "$@"
EOF
    chmod +x /usr/local/bin/x86_64-w64-mingw32-pkg-config
fi

./build-qga-windows.sh

# Stage a distributable folder: exe + required mingw DLLs
DIST=/src/dist/qemu-ga-11.1.2-windows-x86_64
mkdir -p "$DIST"
cp qemu/build-win/qga/qemu-ga.exe "$DIST/"
SYSBIN=/usr/x86_64-w64-mingw32/sys-root/mingw/bin
for dll in $(x86_64-w64-mingw32-objdump -p qemu/build-win/qga/qemu-ga.exe | awk '/DLL Name/ {print $3}' | sort -u); do
    if [ -f "$SYSBIN/$dll" ]; then
        cp "$SYSBIN/$dll" "$DIST/"
    else
        echo "note: $dll is a Windows system DLL, not bundled"
    fi
done
ls -la "$DIST"
EOS
