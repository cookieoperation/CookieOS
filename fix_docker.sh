#!/bin/bash

echo "🛑 Stopping all Docker processes..."
killall Docker 2>/dev/null
killall com.docker.backend 2>/dev/null
killall com.docker.vpnkit 2>/dev/null
killall com.docker.hyperkit 2>/dev/null
killall com.docker.vmnetd 2>/dev/null

echo "⏳ Waiting for processes to close..."
sleep 3

echo "🗑️  Clearing Docker Desktop cache and state files..."
rm -rf ~/Library/Containers/com.docker.docker
rm -rf ~/Library/Group\ Containers/group.com.docker
rm -rf ~/Library/Application\ Support/Docker\ Desktop
rm -rf ~/.docker/config.json
rm -rf ~/Library/Preferences/com.docker.docker.plist
rm -rf ~/Library/Saved\ Application\ State/com.electron.docker-frontend.savedState
rm -rf ~/Library/Caches/com.docker.docker

echo "🚀 Restarting Docker Desktop..."
open -a Docker

echo "✅ Done! Docker has been completely factory reset."
echo "Wait about 30-60 seconds for the Whale icon to appear in your menu bar."
