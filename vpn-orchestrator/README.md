# VPN Orchestrator

This container starts and recreates the separate Portainer stacks that use `network_mode: container:vpn`. It replaces the runtime responsibilities of the archived `vpn-watchdog` and `portainer-orchestration.sh` for VPN-dependent containers.

## Prerequisites

Create a Portainer access token with permission to manage stacks on endpoint `3`. Store it as the `PORTAINER_API_KEY` environment variable on the `vpn-orchestrator` stack in Portainer. The Compose file requires this variable and passes it to the container without committing the value to this repository.

The six dependent Portainer stack IDs are recorded in the `DEPENDENTS` value inside `docker-compose.yml`. Update those IDs if the stacks are deleted and recreated in Portainer.

## Cutover

Do not run this orchestrator alongside the old watchdog or startup script:

1. Disable the NAS task that runs the separately copied `portainer-orchestration.sh`.
2. Stop and remove the existing `vpn-watchdog` Portainer stack.
3. Redeploy the six VPN-dependent stacks so their new `restart: on-failure` policies take effect.
4. Deploy the `vpn-orchestrator` stack.
5. Confirm its logs show the VPN becoming healthy and all six dependent stacks reconciling successfully.

The retired watchdog remains under `_archive/vpn-watchdog` for reference.

## Verification

Test VPN replacement:

1. Recreate or update the `vpn` stack so its container ID changes.
2. Confirm the orchestrator waits for the new VPN container to become healthy.
3. Confirm BitTorrent, Prowlarr, Sonarr, Radarr, Lidarr, and Bazarr are recreated and become healthy.

Test NAS startup:

1. Restart the NAS.
2. Confirm Portainer, VPN, and VPN Orchestrator start through `restart: unless-stopped`.
3. Confirm the dependent containers do not start before the VPN is healthy.
4. Confirm the orchestrator starts the missing dependent stacks and they become healthy.

## How it works

The orchestrator polls the VPN container rather than relying on transient Docker events. A changed VPN container ID causes all dependent stacks to be stopped and started in parallel through Portainer so they join the replacement network namespace. On orchestrator startup, only missing or unhealthy dependents are reconciled. During steady state, an unhealthy dependent receives a 60-second grace period for intentional maintenance and is reconciled by itself only if it remains unhealthy. Every reconciliation waits for the VPN and the complete dependent group to be healthy before recording success.

The VPN container ID and heartbeat state live under `/Volume1/public/docker-configs/vpn-orchestrator`. The Portainer token is supplied through the stack's `PORTAINER_API_KEY` variable. The orchestration script is inline in `docker-compose.yml` because Portainer GitOps deploys the selected Compose file without making adjacent repository files available to runtime bind mounts or file-backed configs.
