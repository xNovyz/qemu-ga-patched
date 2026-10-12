#!/usr/bin/env bash
# Applies the patches in patches/ to the qemu submodule and builds qemu-ga.
# Requires qemu build deps: meson, ninja, python3, glib-2.0, pkg-config.
set -euo pipefail
cd "$(dirname "$0")"

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

mkdir -p qemu/build
cd qemu/build
if [ ! -f build.ninja ]; then
    ../configure --target-list=x86_64-softmmu --enable-guest-agent
fi
make -j"$(nproc)" qemu-ga
echo "Built: $(pwd)/qga/qemu-ga"
