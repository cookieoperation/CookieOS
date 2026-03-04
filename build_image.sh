set -euo pipefail
# CookieOS "Super Check" & Optimized Image Builder v7.2
# Features: Robust Mounts, Rootfs Caching, Exhaustive Boot Verification.

# Helper for critical failures
declare_fail() {
    local msg=$1
    local criticality=${2:-"CRITICAL"}
    echo "-----------------------------------"
    echo "❌ $criticality FAILURE: $msg"
    echo "💡 Reason: Build ended early because a required task could not be completed at this stage."
    echo "🔍 Diagnostic: Check logs above for the specific command that failed."
    echo "-----------------------------------"
    exit 1
}

# Global error trap
trap 'echo "Error on line $LINENO"; declare_fail "An unexpected error occurred." "UNEXPECTED"' ERR

check_deps() {
    echo "🔍 Checking build dependencies..."
    local deps=("parted" "mkfs.vfat" "mkfs.ext4" "debootstrap" "losetup" "truncate" "npm")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            declare_fail "Missing required build tool: $dep" "BLOCKING"
        fi
    done
    echo "✅ All dependencies present."
}

check_deps

echo "🍪 CookieOS Build System v7.2 (Robust Foundation)"

IMG_NAME="cookieos_standalone_v6.0.img"
MOUNT_DIR="/mnt/cookie_root"
BOOT_DIR="$MOUNT_DIR/boot"
CACHE_DIR="/build/cache"
ROOTFS_TAR="$CACHE_DIR/cookieos_base_rootfs.tar.gz"
ARCH="arm64"
SUITE="bookworm"
LDEV=""

# Ensure we are running as root
if [ "$EUID" -ne 0 ]; then
    declare_fail "This script must be run as root (or inside the Docker builder)." "BLOCKING"
fi

# Flags
CHECK_ONLY=false
NO_CACHE=false
CLEAN_BUILD=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --check-only) CHECK_ONLY=true ;;
        --no-cache) NO_CACHE=true ;;
        --clean) CLEAN_BUILD=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

cleanup() {
    echo "🧹 Cleaning up..."
    # Unmount in reverse order with lazy/force fallback
    if mountpoint -q "$BOOT_DIR" 2>/dev/null; then umount -l "$BOOT_DIR" || umount -f "$BOOT_DIR" || true; fi
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then umount -l "$MOUNT_DIR" || umount -f "$MOUNT_DIR" || true; fi
    
    # Detach specific loop device
    if [ -n "${LDEV:-}" ]; then
        losetup -d "$LDEV" 2>/dev/null || true
    fi
    
    # Clean up any other leaked loops for this specific image name
    for loop in $(losetup -j "$IMG_NAME" | cut -d: -f1); do
        echo "🔗 Detaching leaked loop: $loop"
        losetup -d "$loop" 2>/dev/null || true
    done
    
    [ -d "$MOUNT_DIR" ] && rm -rf "$MOUNT_DIR"
    echo "✨ Cleanup complete."
}

trap cleanup EXIT

super_check() {
    local target_img=$1
    local standalone=${2:-false}
    local internal_ldev=""
    local internal_mount="/mnt/check_root"
    local internal_boot="$internal_mount/boot"

    echo "🔍 Running Super Check..."

    if [ "$standalone" = "true" ]; then
        if [ ! -f "$target_img" ]; then echo "❌ Error: Image not found!"; return 1; fi
        internal_ldev=$(losetup -fP --show "$target_img")
        mkdir -p "$internal_boot"
        mount "${internal_ldev}p2" "$internal_mount"
        mount "${internal_ldev}p1" "$internal_boot"
    else
        internal_mount="$MOUNT_DIR"
        internal_boot="$BOOT_DIR"
    fi

    # Exhaustive list of RPi 4/5 boot requirements
    REQUIRED_BOOT_FILES=(
        "bootcode.bin" "start.elf" "fixup.dat"
        "start4.elf" "fixup4.dat" "kernel8.img"
        "config.txt" "cmdline.txt" "initramfs"
        "bcm2711-rpi-4-b.dtb" "bcm2712-rpi-5-b.dtb"
    )

    MISSING=0
    for file in "${REQUIRED_BOOT_FILES[@]}"; do
        if [ ! -f "$internal_boot/$file" ]; then
            echo "❌ Missing critical boot file: $file"
            MISSING=$((MISSING + 1))
        fi
    done

    if [ ! -d "$internal_boot/overlays" ] || [ -z "$(ls -A "$internal_boot/overlays" 2>/dev/null)" ]; then
        echo "❌ Overlays directory is missing or empty!"
        MISSING=$((MISSING + 1))
    fi

    if [ ! -f "$internal_mount/opt/cookieos/server.ts" ]; then
        echo "❌ Application server is missing from rootfs!"
        MISSING=$((MISSING + 1))
    fi

    if [ ! -f "$internal_mount/sbin/init" ]; then
        echo "❌ Critical binary /sbin/init is missing! RootFS is likely incomplete."
        MISSING=$((MISSING + 1))
    fi

    if [ "$standalone" = "true" ]; then
        umount "$internal_boot" || true
        umount "$internal_mount" || true
        losetup -d "$internal_ldev" || true
    fi

    if [ $MISSING -eq 0 ]; then
        echo "✅ Super Check Passed!"
    else
        echo "❌ Super Check Failed! Found $MISSING errors."
        exit 1
    fi
}

if [ "$CHECK_ONLY" = true ]; then
    super_check "$IMG_NAME" true
    exit 0
fi

echo "🍪 CookieOS Build Orchestrator v7.2"
echo "-----------------------------------"
echo "🚀 Starting build process..."

echo "📂 Ensuring cache directory exists..."
mkdir -pv "$CACHE_DIR"

if [ "$NO_CACHE" = true ] || [ "$CLEAN_BUILD" = true ]; then
    echo "🗑️  Clearing cache and existing image..."
    rm -f "$ROOTFS_TAR"
    [ "$CLEAN_BUILD" = true ] && rm -f "$IMG_NAME"
fi

# 1. Build Host dependencies (if any)
if [ -f "package.json" ]; then
    echo "📦 Checking application dependencies..."
    npm install || declare_fail "npm install failed!" "VITAL"
fi

# 2. Prepare Image
SKIP_FORMATTING=false
if [ -f "$IMG_NAME" ] && [ "$CLEAN_BUILD" = false ]; then
    echo "♻️  Existing image found. Entering INCREMENTAL MODE..."
    SKIP_FORMATTING=true
else
    echo "[1/7] Creating 4GB blank image..."
    rm -f "$IMG_NAME" # Ensure it's empty
    truncate -s 4GB "$IMG_NAME"
    parted "$IMG_NAME" --script mklabel msdos || declare_fail "Failed to create partition table." "CRITICAL"
    parted "$IMG_NAME" --script mkpart primary fat32 2048s 256MiB || declare_fail "Failed to create boot partition." "CRITICAL"
    parted "$IMG_NAME" --script mkpart primary ext4 256MiB 100% || declare_fail "Failed to create root partition." "CRITICAL"
    parted "$IMG_NAME" --script set 1 boot on || declare_fail "Failed to set boot flag." "WARNING"
fi

# 3. Mounts
echo "[2/7] Setup Loop Device and Mounting..."
LDEV=$(losetup -fP --show "$IMG_NAME") || declare_fail "Could not setup loop device. Are Loop modules loaded?" "BLOCKING"
sleep 2

if [ "$SKIP_FORMATTING" = false ]; then
    echo "✨ Formatting partitions..."
    mkfs.vfat -F 32 -n BOOT "${LDEV}p1"
    mkfs.ext4 -L ROOTFS "${LDEV}p2"
fi

mkdir -p "$MOUNT_DIR"
mount "${LDEV}p2" "$MOUNT_DIR" || declare_fail "Failed to mount RootFS partition." "CRITICAL"
mkdir -p "$BOOT_DIR"
mount "${LDEV}p1" "$BOOT_DIR" || declare_fail "Failed to mount Boot partition." "CRITICAL"

# 4. Bootstrap / Update
ROOTFS_ALREADY_PRESENT=false
if [ -d "$MOUNT_DIR/etc" ] && [ -d "$MOUNT_DIR/usr" ]; then
    echo "📂 Existing RootFS detected in image. Skipping Bootstrap..."
    ROOTFS_ALREADY_PRESENT=true
fi

if [ "$ROOTFS_ALREADY_PRESENT" = true ]; then
    echo "[3/7] ⚡ Preparing In-Place Update..."
    # Ensure RPi repos are there just in case
    if [ ! -f "$MOUNT_DIR/etc/apt/sources.list.d/raspi.list" ]; then
        echo "📋 Restoring missing RPi repositories..."
        curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key | gpg --dearmor -o "$MOUNT_DIR/usr/share/keyrings/raspberrypi-archive-keyring.gpg"
        echo "deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.gpg] http://archive.raspberrypi.org/debian/ $SUITE main" > "$MOUNT_DIR/etc/apt/sources.list.d/raspi.list"
    fi
      chroot "$MOUNT_DIR" /bin/bash -c "
        set -e
        apt-get update
        echo '📦 Installing Pre-requisites...'
        apt-get install -y --no-install-recommends curl ca-certificates lsb-release
        
        echo '📦 Adding Waydroid Repository...'
        curl -fsSL https://repo.waydro.id | bash

        echo '📦 Installing core system components...'
        apt-get install -y --no-install-recommends \\
            linux-image-rpi-v8 raspberrypi-bootloader raspi-config \\
            firmware-brcm80211 net-tools ifupdown sudo curl \\
            weston labwc xwayland waydroid mesa-utils python3-requests python3-flask python3-werkzeug \\
            rustc cargo libfontconfig1-dev libgtk-3-dev libwebkit2gtk-4.0-dev



        
        echo '📦 Installing Ollama (AI Engine)...'
        curl -fsSL https://ollama.com/install.sh | sh

        
        echo '📦 Installing application dependencies...'
        apt-get install -y --no-install-recommends nodejs npm ssh
        
        # Ensure initramfs includes all necessary drivers
        echo 'MODULES=most' > /etc/initramfs-tools/conf.d/driver-policy
        update-initramfs -u
        
        echo '🧠 Pre-pulling Llama 3 for the AI Shell...'
        ollama serve &
        SERV_PID=\$!
        sleep 10
        ollama pull llama3
        kill \$SERV_PID || true
        
        # Cleanup to save space
        apt-get clean

        rm -rf /var/lib/apt/lists/*
    "
elif [ -f "$ROOTFS_TAR" ]; then
    echo "[3/7] ⚡ Restoring rootfs from cache..."
    tar -xzf "$ROOTFS_TAR" -C "$MOUNT_DIR"
    
    # Restore /boot contents from internal backup if it exists
    if [ -d "$MOUNT_DIR/opt/cookieos/boot_backup" ]; then
        echo "📂 Restoring boot partition from internal backup..."
        cp -r "$MOUNT_DIR/opt/cookieos/boot_backup/"* "$BOOT_DIR/"
    fi
else
    echo "[3/7] 🐢 Bootstrapping Debian $SUITE..."
    debootstrap --arch=$ARCH --foreign --variant=minbase "$SUITE" "$MOUNT_DIR" http://deb.debian.org/debian/
    cp /usr/bin/qemu-aarch64-static "$MOUNT_DIR/usr/bin/"
    chroot "$MOUNT_DIR" /debootstrap/debootstrap --second-stage

    # Repos
    cat <<EOF > "$MOUNT_DIR/etc/apt/sources.list"
deb http://deb.debian.org/debian $SUITE main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $SUITE-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $SUITE-security main contrib non-free non-free-firmware
EOF
    curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key | gpg --dearmor -o "$MOUNT_DIR/usr/share/keyrings/raspberrypi-archive-keyring.gpg"
    echo "deb [signed-by=/usr/share/keyrings/raspberrypi-archive-keyring.gpg] http://archive.raspberrypi.org/debian/ $SUITE main" > "$MOUNT_DIR/etc/apt/sources.list.d/raspi.list"

    chroot "$MOUNT_DIR" /bin/bash -c "
        set -e
        apt-get update
        echo '📦 Installing Pre-requisites...'
        apt-get install -y --no-install-recommends curl ca-certificates lsb-release
        
        echo '📦 Adding Waydroid Repository...'
        curl -fsSL https://repo.waydro.id | bash

        echo '📦 Installing core system components...'
        apt-get install -y --no-install-recommends \\
            linux-image-rpi-v8 raspberrypi-bootloader raspi-config \\
            firmware-brcm80211 net-tools ifupdown sudo curl \\
            weston labwc xwayland waydroid mesa-utils python3-requests python3-flask python3-werkzeug \\
            rustc cargo libfontconfig1-dev libgtk-3-dev libwebkit2gtk-4.0-dev



        
        echo '📦 Installing Ollama (AI Engine)...'
        curl -fsSL https://ollama.com/install.sh | sh

        
        echo '📦 Installing application dependencies...'
        apt-get install -y --no-install-recommends nodejs npm ssh

        # Ensure initramfs includes all necessary drivers
        echo 'MODULES=most' > /etc/initramfs-tools/conf.d/driver-policy
        update-initramfs -u
        
        echo '🧠 Pre-pulling Llama 3 for the AI Shell...'
        ollama serve &
        SERV_PID=\$!
        sleep 10
        ollama pull llama3
        kill \$SERV_PID || true

        # Cleanup to save space
        apt-get clean

        rm -rf /var/lib/apt/lists/*

        # Prepare Native AOSP Smash
        echo '🏗️ Preparing Native AOSP Smash (Direct Mounting)...'
        mkdir -p "$MOUNT_DIR/android/system" "$MOUNT_DIR/android/vendor" "$MOUNT_DIR/android/data"
    "
fi

# 5. Core Injection & Sync
# 5. Core Injection & Sync
echo "[4/7] Applying Identity & Smashed Image Injection..."
echo "cookieos" > "$MOUNT_DIR/etc/hostname"

cat <<EOF > "$MOUNT_DIR/etc/fstab"
LABEL=BOOT  /boot           vfat    defaults          0       2
LABEL=ROOTFS /               ext4    defaults,noatime  0       1
# Native AOSP Fusion Mounts
/opt/cookieos/android_system.img  /android/system  ext4  ro,loop  0  0
/opt/cookieos/android_vendor.img  /android/vendor  ext4  ro,loop  0  0
EOF

mkdir -p "$MOUNT_DIR/opt/cookieos"
# No more dist/ HTML/ CSS

cp ai_shell.py "$MOUNT_DIR/usr/local/bin/ai-shell"
chmod +x "$MOUNT_DIR/usr/local/bin/ai-shell"


cp ai_app_builder.py "$MOUNT_DIR/usr/local/bin/ai-app-builder"
chmod +x "$MOUNT_DIR/usr/local/bin/ai-app-builder"
mkdir -p "$MOUNT_DIR/opt/cookieos/apps"

# Inject local fusion images if present
[ -f "./android_system.img" ] && cp ./android_system.img "$MOUNT_DIR/opt/cookieos/"
[ -f "./android_vendor.img" ] && cp ./android_vendor.img "$MOUNT_DIR/opt/cookieos/"

# Inject Settings Application APKs
if [ -f "android_settings_app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo "📱 Injecting Kotlin Settings APK..."
    mkdir -p "$MOUNT_DIR/opt/cookieos/apks"
    cp "android_settings_app/build/outputs/apk/debug/app-debug.apk" "$MOUNT_DIR/opt/cookieos/apks/CookieSettings.apk"
fi

if [ -f "android_files_app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo "📂 Injecting Kotlin Files APK..."
    mkdir -p "$MOUNT_DIR/opt/cookieos/apks"
    cp "android_files_app/build/outputs/apk/debug/app-debug.apk" "$MOUNT_DIR/opt/cookieos/apks/CookieFiles.apk"
fi

if [ -f "cookie_daemon.py" ]; then
    echo "🐍 Injecting CookieDaemon..."
    cp cookie_daemon.py "$MOUNT_DIR/opt/cookieos/"
    chmod +x "$MOUNT_DIR/opt/cookieos/cookie_daemon.py"
    
    cat <<EOF > "$MOUNT_DIR/etc/systemd/system/cookie-daemon.service"
[Unit]
Description=CookieOS Bridge Daemon
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/cookieos/cookie_daemon.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    chroot "$MOUNT_DIR" systemctl enable cookie-daemon
fi

# Compile Native JSX Shell (Dioxus)
echo "🦀 Compiling Native JSX Shell (Dioxus)..."
cp Cargo.toml "$MOUNT_DIR/opt/cookieos/"
cp -r src "$MOUNT_DIR/opt/cookieos/"
cp src/bot_mascot.png "$MOUNT_DIR/opt/cookieos/bot_mascot.png"
cp -r src/wallpaper "$MOUNT_DIR/opt/cookieos/"
cp -r src/icons "$MOUNT_DIR/opt/cookieos/"
chroot "$MOUNT_DIR" /bin/bash -c "
    cd /opt/cookieos
    cargo build --release
    cp target/release/aluminum-shell /usr/local/bin/
    rm -rf target
"


cp app_converter.sh "$MOUNT_DIR/usr/local/bin/app-converter"
chmod +x "$MOUNT_DIR/usr/local/bin/app-converter"


# Desktop Shell Integration
echo "🖥️ Integrating Aluminum Desktop Shell..."
cp aluminum-desktop.service "$MOUNT_DIR/etc/systemd/system/"
mkdir -p "$MOUNT_DIR/opt/cookieos"
cp autostart "$MOUNT_DIR/opt/cookieos/"
chmod +x "$MOUNT_DIR/opt/cookieos/autostart"

chroot "$MOUNT_DIR" /bin/bash -c "
    systemctl enable aluminum-desktop
    # Disable standard login getty to favor our shell
    systemctl disable getty@tty1
"

echo "[5/7] Exhaustive Boot Synchronization..."



# Search for firmware in all common locations
FW_PATHS=(
    "$MOUNT_DIR/usr/lib/raspberrypi-bootloader"
    "$MOUNT_DIR/usr/lib/raspi-firmware"
    "$MOUNT_DIR/boot"
)

for path in "${FW_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "🔍 Found firmware path at $path, syncing .elf, .dat, .bin..."
        cp "$path"/*.elf "$path"/*.dat "$path"/*.bin "$BOOT_DIR/" 2>/dev/null || true
    fi
done

# Kernel sync
echo "🔍 Syncing Kernel & Initramfs..."
if find "$MOUNT_DIR/boot" -name "vmlinuz*" -print -quit | grep -q .; then
    LATEST_VMLINUZ=$(ls -v "$MOUNT_DIR/boot"/vmlinuz* | tail -n 1)
    echo "📋 Copying $LATEST_VMLINUZ to kernel8.img..."
    cp "$LATEST_VMLINUZ" "$BOOT_DIR/kernel8.img"
    
    LATEST_INITRD=$(ls -v "$MOUNT_DIR/boot"/initrd.img* 2>/dev/null | tail -n 1)
    if [ -n "$LATEST_INITRD" ]; then
        echo "📋 Copying $LATEST_INITRD to initramfs..."
        cp "$LATEST_INITRD" "$BOOT_DIR/initramfs"
    fi
elif [ -f "$MOUNT_DIR/boot/kernel8.img" ]; then
    echo "📋 Copying kernel8.img to boot partition..."
    cp "$MOUNT_DIR/boot/kernel8.img" "$BOOT_DIR/"
fi

# DTBs and Overlays
echo "🔍 Syncing DTBs and Overlays..."
mkdir -p "$BOOT_DIR/overlays"
SEARCH_DTB_PATHS=(
    "$MOUNT_DIR/usr/lib"
    "$MOUNT_DIR/boot"
    "$MOUNT_DIR/lib/modules"
    "$MOUNT_DIR/usr/lib/raspi-firmware"
)

for search_path in "${SEARCH_DTB_PATHS[@]}"; do
    if [ -d "$search_path" ]; then
        find "$search_path" -name "*2711-rpi-4*.dtb" -exec cp -v {} "$BOOT_DIR/" \; 2>/dev/null || true
        find "$search_path" -name "*2712-rpi-5*.dtb" -exec cp -v {} "$BOOT_DIR/" \; 2>/dev/null || true
        find "$search_path" -name "*.dtbo" -exec cp -v {} "$BOOT_DIR/overlays/" \; 2>/dev/null || true
    fi
done

# Get Disk Identifier for PARTUUID
# Note: hexdump -e '1/4 "%08x" "\n"' reads 4 bytes and formats as hex
DISK_ID=$(dd if="$IMG_NAME" bs=1 count=4 skip=440 2>/dev/null | hexdump -v -e '1/4 "%08x" "\n"')
echo "🆔 Disk Identifier: $DISK_ID"

# Boot Config
cat <<EOF > "$BOOT_DIR/config.txt"
# CookieOS RPi Boot Config
arm_64bit=1
disable_overscan=1
dtoverlay=vc4-kms-v3d
# Explicitly load initramfs
initramfs initramfs followkernel
EOF

# Use PARTUUID for maximum stability and enable Native Android Drivers (Binder/Ashmem)
echo "console=serial0,115200 console=tty1 root=PARTUUID=${DISK_ID}-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait rootdelay=5 binder.devices=binder,hwbinder,vndbinder,admin_binder binder.debug_mask=0" > "$BOOT_DIR/cmdline.txt"

# 7. Internal Backup for Cache
echo "[6/7] Creating internal boot backup for cache..."
mkdir -p "$MOUNT_DIR/opt/cookieos/boot_backup"
cp -r "$BOOT_DIR/"* "$MOUNT_DIR/opt/cookieos/boot_backup/"

# Only save cache if it doesn't exist
if [ ! -f "$ROOTFS_TAR" ] || [ "$NO_CACHE" = true ]; then
    echo "💾 Creating rootfs cache..."
    tar -czf "$ROOTFS_TAR" -C "$MOUNT_DIR" --exclude='./boot/*' --exclude='./dev/*' --exclude='./proc/*' --exclude='./sys/*' .
    sync
fi

# 8. Super Check
super_check "$IMG_NAME" false

echo "💾 Syncing to disk..."
sync

echo "-----------------------------------"
echo "🎉 Build Complete! Artifact: $IMG_NAME"
echo "🍪 CookieOS Aluminum Edition is ready to flash."
echo "-----------------------------------"
