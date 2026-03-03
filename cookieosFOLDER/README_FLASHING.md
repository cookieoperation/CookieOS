# 🍪 CookieOS Aluminum: Imaging & Flashing Guide

Follow these steps to flash your CookieOS image to a microSD card for your Raspberry Pi 5.

## 💾 Prerequisites
- A MicroSD Card (SanDisk Extreme or similar recommended, 16GB+).
- The generated image: `cookieos_standalone_v6.0.img`.
- A computer with an SD card reader.

## 🚀 Recommended Tool: Raspberry Pi Imager
1. **Download**: Install [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. **Select OS**: Click 'Choose OS', scroll to the bottom, and select **'Use custom'**.
3. **Select File**: Choose your `cookieos_standalone_v6.0.img`.
4. **Choose Storage**: Select your MicroSD card.
5. **Write**: Click **'Next'** and then **'Write'**.

## 🐧 Alternative (Linux/macOS terminal)
> [!CAUTION]
> The `dd` command is powerful. Ensure you have the correct destination device (`/dev/sdX` or `/dev/diskX`) to avoid data loss.

```bash
# Verify your SD card device path first!
# macOS: diskutil list
# Linux: lsblk

sudo dd if=cookieos_standalone_v6.0.img of=/dev/TARGET_DISK bs=4M status=progress conv=fsync
```

## 🛠️ Post-Flashing Tips
- **Eject Safely**: Always eject the card properly before removing it.
- **First Boot**: The first boot on the RPi 5 may take 1-2 minutes as it initializes the native AOSP smash mounts and pull any remaining AI model data.
- **Connection**: Ensure you are using a 5V/5A power supply for the RPi 5 to prevent stability issues.

## ❓ Troubleshooting
- **No Video**: Ensure `dtoverlay=vc4-kms-v3d` is in `config.txt` (the build system does this automatically).
- **Infinite Loop**: If the build fails, check the **Short Declaration** at the end of the build log for the criticality and reason.
