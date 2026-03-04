# 🍪 CookieOS Final Build & Flash Instructions

Follow these steps to build and flash CookieOS for your Raspberry Pi 4 or 5.

## 1. Build the Docker Builder
Ensure you have the latest build environment with all dependencies (including `hexdump`).
```bash
docker build -t cookieos-builder .
```

## 2. Generate the OS Image
You can use the standard Docker command or `docker-compose`.

### Using Docker Compose (Recommended):
First, ensure your builder image is up to date:
```bash
docker-compose build
```
Then run the build:
```bash
docker-compose up build
```

**For a clean build (removes cache and existing image):**
```bash
docker-compose run --rm build --clean
```

### Using standard Docker:
```bash
docker run --privileged -v $(pwd):/build cookieos-builder
```
*Note: `--privileged` and volume mounting are required for loop device management.*

## 3. Flash to SD Card
Identify your SD card device (e.g., `/dev/sda` or `/dev/disk4`) and use the flashing tool.

### On macOS:
```bash
./flash.sh /dev/diskX
```
### On Linux:
```bash
sudo ./flash.sh /dev/sdX
```

## 4. Boot your Raspberry Pi
1. Insert the SD card into your RPi.
2. Connect power.
3. CookieOS should boot into the terminal/application layer.

### Troubleshooting
- If it fails to boot, check the `config.txt` and `cmdline.txt` on the BOOT partition.
- Ensure the `initramfs` file exists in the BOOT partition.
