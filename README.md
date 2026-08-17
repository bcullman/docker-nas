# Docker NAS

Docker Compose definitions for the services running on the NAS. Each active application has its own directory and Portainer stack, with Portainer GitOps tracking the corresponding `docker-compose.yml` on the `main` branch.

Application data is stored outside this repository under `/Volume1/public/docker-configs`. Media is stored under `/Volume2/media`. This repository contains deployment configuration only; credentials are supplied through Portainer and must not be committed.

## Services

| Stack | Purpose | Networking |
| --- | --- | --- |
| `adguard` | DNS and network filtering | Host |
| `bazarr` | Subtitle management | VPN container |
| `bittorrent` | BitTorrent client | VPN container |
| `cloudflare` | Cloudflare Tunnel | Compose-managed |
| `homebridge` | HomeKit bridge | Host |
| `homepage` | Service dashboard | Compose-managed |
| `lidarr` | Music management | VPN container |
| `maintainerr` | Media cleanup | Compose-managed |
| `myspeed` | Internet speed monitoring | Compose-managed |
| `peanut` | UPS monitoring | Compose-managed |
| `plex` | Media server | Host |
| `prowlarr` | Indexer management | VPN container |
| `radarr` | Movie management | VPN container |
| `scrutiny` | Drive health monitoring | Compose-managed |
| `seerr` | Media requests | Compose-managed |
| `sonarr` | TV series management | VPN container |
| `tautulli` | Plex activity monitoring | Compose-managed |
| `tdarr` | Media transcoding | Host |
| `vpn` | NordVPN network namespace | Compose-managed |
| `vpn-orchestrator` | VPN-dependent stack orchestration | Compose-managed |
| `wud` | Container update monitoring | Compose-managed |

Retired services are kept under `_archive/` and are not part of the active deployment.

## Networking

Active stacks use three networking patterns:

- **Compose-managed:** `network_mode` is omitted, so Compose creates an isolated bridge network for the stack. Published ports provide access from the NAS and LAN. This is the default for ordinary services.
- **Host:** `network_mode: host` shares the NAS network namespace. Use it only for services that need host-bound networking, LAN discovery, or multicast.
- **VPN container:** `network_mode: container:vpn` shares the VPN container's network namespace. These services publish their ports through the `vpn` stack rather than through their own Compose files.

Do not use the legacy explicit `network_mode: bridge` setting for new services. Omit `network_mode` unless host networking or VPN sharing is required.

## Deployment

Each application is deployed as a separate Portainer stack from this Git repository:

1. Create a stack using **Repository** as the build method.
2. Select this repository and the `main` branch.
3. Set the Compose path to `<stack>/docker-compose.yml`.
4. Add that stack's required variables in Portainer under **Environment variables**.
5. Deploy the stack and enable GitOps polling.

Portainer uses these values for Compose interpolation during deployment. They are stack-scoped values stored by Portainer, not environment variables inherited automatically from the NAS host. Do not put secret values in a committed `.env` or `stack.env` file.

The Compose expressions use `${VARIABLE:?Set VARIABLE in Portainer}`, so deployment fails immediately with a useful message when a required value is absent.

## Required Portainer variables

This is the comprehensive inventory of deployment-managed variables referenced by active Compose files. Add each variable only to the stack shown; values do not need to be duplicated across unrelated stacks.

| Variable | Portainer stack | Purpose |
| --- | --- | --- |
| `ADGUARD_USERNAME` | `adguard` | AdGuard credentials used by the Homepage widget |
| `ADGUARD_PASSWORD` | `adguard` | AdGuard credentials used by the Homepage widget |
| `BAZARR_API_KEY` | `bazarr` | Bazarr API key used by the Homepage widget |
| `BITTORRENT_USERNAME` | `bittorrent` | qBittorrent credentials used by the Homepage widget |
| `BITTORRENT_PASSWORD` | `bittorrent` | qBittorrent credentials used by the Homepage widget |
| `CLOUDFLARE_ACCOUNT_ID` | `cloudflare` | Cloudflare account identifier used by the Homepage widget |
| `CLOUDFLARE_TUNNEL_ID` | `cloudflare` | Cloudflare tunnel identifier used by the Homepage widget |
| `CLOUDFLARE_HOMEPAGE_API_TOKEN` | `cloudflare` | Cloudflare API token used by the Homepage widget |
| `CLOUDFLARE_TUNNEL_TOKEN` | `cloudflare` | Token used by `cloudflared` to run the tunnel |
| `HOMEBRIDGE_USERNAME` | `homebridge` | Homebridge credentials used by the Homepage widget |
| `HOMEBRIDGE_PASSWORD` | `homebridge` | Homebridge credentials used by the Homepage widget |
| `LIDARR_API_KEY` | `lidarr` | Lidarr API key used by the Homepage widget |
| `PEANUT_API_KEY` | `peanut` | PeaNUT API key used by the Homepage widget |
| `PLEX_API_TOKEN` | `plex` | Plex API token used by the Homepage widget |
| `PLEX_CLAIM_TOKEN` | `plex` | Plex server claim token passed to the container |
| `PORTAINER_API_KEY` | `vpn-orchestrator` | Portainer access token used to stop and start dependent stacks |
| `PROWLARR_API_KEY` | `prowlarr` | Prowlarr API key used by the Homepage widget |
| `RADARR_API_KEY` | `radarr` | Radarr API key used by the Homepage widget |
| `SEERR_API_KEY` | `seerr` | Seerr API key used by the Homepage widget |
| `SONARR_API_KEY` | `sonarr` | Sonarr API key used by the Homepage widget |
| `TAUTULLI_API_KEY` | `tautulli` | Tautulli API key used by the Homepage widget |
| `VPN_NORDVPN_TOKEN` | `vpn` | NordVPN access token used to establish the VPN connection |

Other environment entries such as `TZ`, `PUID`, `PGID`, application ports, and image-specific settings are intentionally non-secret and remain directly in the Compose files.

## VPN-dependent stacks

BitTorrent, Prowlarr, Sonarr, Radarr, Lidarr, and Bazarr use `network_mode: container:vpn`. Their ports are published by the `vpn` stack because they share the VPN container's network namespace.

The `vpn-orchestrator` stack coordinates these otherwise separate Portainer projects. It waits for the VPN to become healthy and reconciles missing or unhealthy dependents after NAS startup, VPN replacement, or a sustained failure. Stack operations run in parallel. See [`vpn-orchestrator/README.md`](vpn-orchestrator/README.md) for its behavior, prerequisites, and verification procedure.

The dependent Portainer stack IDs are embedded in `vpn-orchestrator/docker-compose.yml`. Update them if any dependent stack is deleted and recreated in Portainer.

## Updating a stack

1. Edit only the affected stack's `docker-compose.yml` and any directly coupled VPN configuration.
2. Validate the file with `docker compose -f <stack>/docker-compose.yml config --quiet`, supplying required variables for interpolation.
3. Push the change to `main`.
4. Allow Portainer GitOps to poll, or manually select **Pull and redeploy**.
5. Verify the container health check and application logs.

Repository conventions for adding and maintaining Compose files are documented in [`AGENTS.md`](AGENTS.md).

## Credential safety

- Store secret values in the appropriate Portainer stack environment, never in Git.
- Do not commit `.env`, `stack.env`, exported stack definitions, API responses, or diagnostic output containing credentials.
- Use narrowly scoped tokens where the upstream service supports them.
- Rotate a credential if it is exposed in logs, screenshots, shell history, or a commit.
- Removing a secret from the current Compose file does not remove it from existing Git history.
