#!/bin/bash
# CookieOS Flashing Tool

set -e

IMG="cookieos_standalone_v6.0.img"
DEVICE=""
FORCE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -y|--yes) FORCE=true ;;
        *) DEVICE=$1 ;;
    esac
    shift
done

if [ -z "$DEVICE" ] || [ "$DEVICE" == "/dev/null" ]; then
    echo "❌ Error: No target device specified."
    echo "Usage: $0 /dev/[device] [-y]"
    exit 1
fi

if [ ! -f "$IMG" ]; then
    echo "❌ Error: $IMG not found! Build it first."
    exit 1
fi

echo "⚠️  WARNING: You are about to flash $IMG to $DEVICE"
echo "All data on $DEVICE will be PERMANENTLY DELETED."

if [ "$FORCE" = false ]; then
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Detect OS and unmount partitions
OS=$(uname)
if [ "$OS" == "Darwin" ]; then
    echo "🍏 macOS detected. Unmounting partitions..."
    diskutil unmountDisk "$DEVICE" || true
else
    echo "🐧 Linux detected. Unmounting partitions..."
    for part in $(ls "${DEVICE}"* 2>/dev/null); do
        umount "$part" 2>/dev/null || true
    done
fi

echo "🔥 Flashing $IMG to $DEVICE..."
# Use pv for progress if available
if command -v pv >/dev/null 2>&1; then
    pv -tpreb "$IMG" | dd of="$DEVICE" bs=1M conv=fsync
else
    dd if="$IMG" of="$DEVICE" bs=1M conv=fsync
fi

echo "✅ Flash complete! You can now boot CookieOS on your Raspberry Pi."
