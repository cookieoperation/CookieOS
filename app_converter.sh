#!/bin/bash
# CookieOS Aluminum App Converter v1.0
# Helper to manage .deb and .apk packages

case "$1" in
    "install-deb")
        echo "📦 Installing Linux app ($2)..."
        sudo apt install "$2"
        ;;
    "install-apk")
        echo "📱 Installing Android app ($2)..."
        waydroid app install "$2"
        ;;
    "list")
        echo "📋 Installed Linux Apps:"
        dpkg --get-selections | grep -v deinstall
        echo ""
        echo "📋 Installed Android Apps:"
        waydroid app list
        ;;
    *)
        echo "Usage: app-converter [install-deb|install-apk|list] <package/path>"
        ;;
esac
