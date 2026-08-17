#!/bin/sh

VPN_NAME="vpn"
DEPENDENTS="bittorrent bazarr lidarr prowlarr radarr readarr sonarr"
INTERVAL=30

echo "[Watchdog] Monitoring VPN container: $VPN_NAME"
LAST_ID=""
while true; do
  CURRENT_ID=$(docker inspect --format '{{.Id}}' "$VPN_NAME" 2>/dev/null)
  if [ -z "$CURRENT_ID" ]; then
    echo "[Watchdog] VPN container \"$VPN_NAME\" not found. Retrying..."
  elif [ "$LAST_ID" != "" ] && [ "$CURRENT_ID" != "$LAST_ID" ]; then
    echo "[Watchdog] Detected VPN container restart. Recreating dependents..."
    for name in $DEPENDENTS; do
      echo "[Watchdog] Recreating container: $name"
      docker rm -f "$name"
      docker restart "$name"
    done
  fi
  LAST_ID="$CURRENT_ID"
  sleep $INTERVAL
done
