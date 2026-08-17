#!/bin/sh

PORTAINER_URL="http://192.168.0.250:19000"
ENDPOINT_ID=3
USERNAME="admin"
PASSWORD="jqOvs#&af9V7"
MAX_WAIT_SECONDS=60
CURL="/usr/bin/curl"
JQ="/usr/bin/jq"

# Optional restart flag
RESTART_MODE=0
if [ "$1" = "--restart" ]; then
  RESTART_MODE=1
  echo "🧪 Restart mode enabled — stacks will be force restarted."
fi

# Wait for Portainer API
echo "⏳ Waiting for Portainer API at $PORTAINER_URL..."
i=0
STATUS=""
while [ "$i" -lt "$MAX_WAIT_SECONDS" ]; do
  STATUS=$($CURL -s "$PORTAINER_URL/api/status" | $JQ -r '.Version')
  if [ -n "$STATUS" ]; then
    echo "✅ Portainer is up (version: $STATUS)"
    break
  fi
  sleep 2
  i=$((i + 2))
done

if [ -z "$STATUS" ]; then
  echo "❌ Timed out waiting for Portainer to start."
  exit 1
fi

# Authenticate
JWT=$($CURL -s -X POST "$PORTAINER_URL/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"Username\": \"$USERNAME\", \"Password\": \"$PASSWORD\"}" | $JQ -r '.jwt')

if [ "$JWT" = "null" ] || [ -z "$JWT" ]; then
  echo "❌ Failed to authenticate with Portainer API."
  exit 1
fi

# Start or restart stack by ID
handle_stack() {
  STACK_ID=$1
  LABEL=$2
  STACK_NAME=$(echo "$LABEL" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  echo "🚀 Handling stack: $LABEL (ID: $STACK_ID)..."

  # Get current container info for this stack
  CONTAINERS_JSON=$($CURL -s -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=1")
  STACK_CONTAINERS=$(echo "$CONTAINERS_JSON" | $JQ -r ".[] | select(.Labels[\"com.docker.compose.project\"] == \"$STACK_NAME\")")
  TOTAL=$(echo "$STACK_CONTAINERS" | $JQ -s 'length')
  RUNNING=$(echo "$STACK_CONTAINERS" | $JQ -r 'select(.State == "running")' | wc -l)

  if [ "$TOTAL" -eq 0 ]; then
    echo "⚠️  No containers found for stack '$STACK_NAME'. Skipping."
    return
  fi

  if [ "$RESTART_MODE" -eq 1 ] || [ "$RUNNING" -lt "$TOTAL" ]; then
    echo "🔄 Restarting $LABEL (because $RUNNING of $TOTAL containers are running)..."
    $CURL -s -X POST "$PORTAINER_URL/api/stacks/$STACK_ID/stop?endpointId=$ENDPOINT_ID" \
      -H "Authorization: Bearer $JWT" > /dev/null
    sleep 2
  fi

  echo "🟢 Starting $LABEL..."
  START_RESPONSE=$($CURL -s -X POST "$PORTAINER_URL/api/stacks/$STACK_ID/start?endpointId=$ENDPOINT_ID" \
    -H "Authorization: Bearer $JWT")
  echo "✅ Start response: $START_RESPONSE"

  echo "⏳ Waiting for containers in stack '$STACK_NAME' to be alive..."
  WAIT_TIME=0
  MAX_WAIT=60

  while [ "$WAIT_TIME" -lt "$MAX_WAIT" ]; do
    CONTAINERS_JSON=$($CURL -s -H "Authorization: Bearer $JWT" "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/containers/json?all=1")
    TOTAL=$(echo "$CONTAINERS_JSON" | $JQ -r ".[] | select(.Labels[\"com.docker.compose.project\"] == \"$STACK_NAME\") | .Id" | wc -l)
    ALIVE=$(echo "$CONTAINERS_JSON" | $JQ -r ".[] | select(.Labels[\"com.docker.compose.project\"] == \"$STACK_NAME\" and .State == \"running\") | .Id" | wc -l)

    if [ "$TOTAL" -eq "$ALIVE" ] && [ "$TOTAL" -gt 0 ]; then
      echo "✅ All $ALIVE container(s) in '$LABEL' are alive."
      return
    fi

    echo "⌛ $ALIVE/$TOTAL alive — waiting..."
    sleep 3
    WAIT_TIME=$((WAIT_TIME + 3))
  done

  echo "❌ Timeout waiting for stack '$LABEL'. Proceeding anyway."
}

# === STACKS IN STARTUP ORDER ===
handle_stack 55 "MySpeed"
handle_stack 58 "Peanut"
handle_stack 44 "Whats up Docker"
handle_stack 5  "Homebridge"
handle_stack 14 "AdGuard"
handle_stack 19 "Tautulli"
handle_stack 54 "Seerr"
handle_stack 22 "Plex"
handle_stack 29 "Homepage"
handle_stack 59 "Scrutiny"
handle_stack 60 "Maintaineer"
handle_stack 6  "VPN" # start before vpn dependent stacks
handle_stack 7  "BitTorrent"
handle_stack 10 "Prowlarr"
handle_stack 9  "Sonarr"
handle_stack 11 "Radarr"
handle_stack 13 "Lidarr"
handle_stack 37 "Bazarr"
handle_stack 43 "Tdarr"
handle_stack 41 "VPN Watchdog"
handle_stack 21 "Cloudflare" # must be last