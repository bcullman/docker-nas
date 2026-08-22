# Docker NAS Maintainer Guide

Use this file as the repository-specific source of truth when adding, changing, or removing containers. Preserve the established patterns below unless the image's official documentation requires an exception. Keep changes surgical: do not normalize unrelated Compose files while working on one service.

## Repository layout

- Each active application has its own directory containing `docker-compose.yml`.
- Each Compose file defines exactly one service/container under a top-level `services:` key. Do not place sidecars or tightly coupled supporting containers in the same file; create a separate directory and Compose file for each container. If an application cannot operate without a sidecar, call that requirement out before adding it so the owner can decide whether to deploy the application at all.
- Retired applications live under `_archive/`. Do not use archived files as the primary template when an active equivalent exists.
- Directory names, service names, and `container_name` values normally match. Existing exceptions include `adguard/adguardhome`, `bittorrent/qbittorrent`, and `wud/whatsupdocker`.
- Compose files intentionally omit the obsolete top-level `version` key.

## Canonical service order

Use this order when a field applies:

1. `image`
2. `container_name`
3. `restart`
4. image-specific process settings such as `init` or `privileged`
5. `labels`
6. `network_mode`
7. `volumes`
8. `environment`
9. `healthcheck`
10. `command`
11. `ports`
12. hardware or permission settings such as `devices`, `cap_add`, or `deploy`

Do not add empty sections merely to satisfy the order. Match the nearby YAML style and use two-space indentation.

## Baseline settings

- Use `restart: unless-stopped` except for containers routed through `container:vpn`. VPN dependents use `restart: on-failure` so Docker does not race them against the VPN after a daemon or NAS restart; `vpn-orchestrator` starts them after the VPN is healthy.
- Use an explicit image tag when the project supports one. This repository usually tracks `:latest`; preserve a deliberately pinned tag.
- Add `wud.watch=true` so What's Up Docker monitors the image. WUD is configured with `WUD_WATCHER_LOCAL_WATCHBYDEFAULT=false`, so unlabeled containers are not watched.
- Add `TZ=America/Los_Angeles` when the image supports `TZ`.
- For LinuxServer.io images, use `PUID=0` and `PGID=0`, consistent with the existing NAS deployment.
- Do not assume `PUID`/`PGID` support for other images. Follow the image documentation; `peanut` is an example that requires its mounted directory to be writable by UID/GID 1000 instead.
- Store persistent application state below `/Volume1/public/docker-configs/<directory>` and mount it at the image's documented config/data path.
- Mount shared media as `/Volume2/media:/media` when the application needs the media library.
- Mount `/var/run/docker.sock:/var/run/docker.sock` only when the service must inspect or control Docker.

## Homepage labels

Services shown in Homepage keep their integration entirely in Compose labels. Order labels as follows, omitting unsupported entries:

```yaml
    labels:
      - wud.watch=true
      - homepage.group=<group>
      - homepage.name=<display name>
      - homepage.icon=<dashboard-icons filename>
      - homepage.href=https://<subdomain>.bullman.net
      - homepage.description=<short purpose>
      - homepage.widget.type=<widget type>
      - homepage.widget.url=http://192.168.0.250:<host-visible port>
      - homepage.widget.fields=["fieldOne", "fieldTwo"]
      - homepage.widget.key=<API key when required>
```

Use the established groups consistently:

- `Acquisition`: download clients, indexers, request tools, and media acquisition managers
- `Media`: media servers and media activity tools
- `Monitoring`: system, storage, network-speed, UPS, and container monitoring
- `Network`: DNS, tunnels, and VPN infrastructure
- `Utilities`: general-purpose home and media utilities

Use the public `https://<name>.bullman.net` URL for `homepage.href`. Use the directly reachable LAN URL (`http://192.168.0.250:<port>`) for `homepage.widget.url`, not the public URL. A service without a useful page or supported widget may omit those labels.

Credentials and tokens already exist inline in this repository. Do not expose them in documentation, logs, commit messages, or summaries, and do not copy a credential from one service to another. For a new credential, prefer variable interpolation from a deployment-managed environment when practical. Do not migrate or rotate existing credentials unless explicitly asked.

### Portainer credential migration

Use this proven workflow when moving an inline Compose credential into a Portainer Git stack variable:

- Use globally unique uppercase names in the form `<STACK>_<CREDENTIAL_TYPE>`, adding a purpose when one stack has multiple credentials, such as `CLOUDFLARE_HOMEPAGE_API_TOKEN` and `CLOUDFLARE_TUNNEL_TOKEN`.
- Reference the variable with a required Compose expression so a missing Portainer value fails deployment instead of becoming an empty credential: `${VARIABLE:?Set VARIABLE in Portainer}`.
- Use the LAN API at `http://192.168.0.250:19000`. The Cloudflare URL redirects and is not the direct API route.
- Authenticate Portainer requests with the `PORTAINER_API_KEY` shell variable in the `X-API-Key` header. Authenticate GitHub operations with `PAT_GIT_CLI`. Load a fresh login shell when these variables were newly added, and never print their values.
- Inspect the stack first with `GET /api/stacks/<id>`. Preserve every existing entry in its `Env` array; the redeploy request replaces this array, so merge the new variable rather than discarding existing variables.
- Before changing Git, call `PUT /api/stacks/<id>/git/redeploy?endpointId=3` with the existing inline credential added to `env`. This establishes the Portainer value while the old Compose definition still works.
- Portainer request fields must use lower camel case even though response-model fields are capitalized. Use `env`, `prune`, `pullImage`, `repullImageAndRedeploy`, `repositoryAuthentication`, `repositoryAuthorizationType`, `repositoryUsername`, `repositoryPassword`, and `repositoryReferenceName`; do not send `Env` or other capitalized request fields.
- These stacks were created with Git authentication enabled. Redeploy with `repositoryAuthentication: true`, `repositoryAuthorizationType: 0`, `repositoryUsername: "bcullman"`, `repositoryPassword` set from `PAT_GIT_CLI`, and `repositoryReferenceName: "refs/heads/main"`. Do not attempt to disable authentication merely because the repository is private or otherwise reachable; Portainer will reuse the stack's incomplete stored credential and cloning will fail.
- After Portainer confirms the variable is stored and non-empty, replace the literal in the Compose file, validate with a non-secret placeholder value, commit only the intended file, and push `main`. Do not upload a separate Compose copy to Portainer; Git remains the source of truth.
- Trigger the same Git redeploy endpoint again with the complete `env` array and Git authentication fields. Verify an HTTP 200 response, confirm `GitConfig.ConfigHash` matches the pushed commit, and use `GET /api/endpoints/3/docker/containers/<name>/json` to confirm the container is running and healthy. Where practical, compare the rendered environment value or label to Portainer's stored variable without displaying either value.
- Do not spend effort rewriting or purging Git history during this migration. The owner plans to recreate the private repository with a clean first commit after the migration is fully accepted.

### Portainer Git stack creation

- When creating a Git-backed stack through the Portainer API, include `additionalFiles: []` in the initial lower-camel-case request even when the stack has no additional Compose files. Omitting it stores `AdditionalFiles` as `null`, which causes Portainer to omit the repository URL and Compose path from the "Redeploy from git repository" section.
- Include `autoUpdate` in the initial creation request with `interval: "5m"`, an empty `webhook`, and both `forceUpdate` and `forcePullImage` set to `false`, matching the existing stacks. Creating the polling configuration afterward does not repair incomplete creation metadata.
- After creation, inspect the stack and verify `AdditionalFiles` is `[]`, `AutoUpdate.Interval` is `5m`, and `GitConfig.URL`, `ReferenceName`, `ConfigFilePath`, and `ConfigHash` are populated before treating it as correctly GitOps-driven.

## Networking and ports

Choose networking based on the service's role:

- Use `network_mode: container:vpn` for acquisition services whose traffic must pass through NordVPN. Do not publish ports in that service's Compose file; keep the expected mappings commented out for discoverability.
- For a VPN-routed service, publish its port on `vpn/docker-compose.yml`. Homepage and other LAN clients reach it through `192.168.0.250:<published port>`.
- Add every VPN-routed Portainer stack ID and container name to `DEPENDENTS` in the inline command in `vpn-orchestrator/docker-compose.yml`. The orchestrator recreates those stacks after the VPN is healthy.
- Use `network_mode: host` only when the application needs host discovery, host-bound protocols, or the established deployment already requires it.
- Otherwise use normal bridge networking (explicit `network_mode: bridge` is acceptable where already established) and publish ports as `<host>:<container>`.
- Annotate non-obvious port purposes, especially when multiple ports are published.
- A `ports` section on a host-networked service is informational/ineffective in Docker; preserve an existing section, but do not add one to a new host-networked service unless the deployment tooling specifically needs it.

When adding or removing a VPN-routed service, treat these as one change set:

1. The service's `docker-compose.yml`.
2. The matching port mapping in `vpn/docker-compose.yml`.
3. The matching Portainer stack ID and container name in the inline command in `vpn-orchestrator/docker-compose.yml`.

### VPN dependency lifecycle

The VPN, orchestrator, and each dependent intentionally remain separate one-container Compose projects. This prevents an application's dependency from forcing multiple containers into its Compose file, but it also means Compose cannot express or reconcile the cross-project dependency.

- `network_mode: container:vpn` makes the dependent join the existing `vpn` container's network namespace. The dependent has no independent IP address or published ports.
- VPN dependents use `restart: on-failure`; all other active services normally use `restart: unless-stopped`. This keeps Docker from starting dependents concurrently with the VPN after a NAS or Docker daemon restart while retaining application-crash recovery.
- Docker starts Portainer, `vpn`, and `vpn-orchestrator` through their `restart: unless-stopped` policies. The orchestrator waits for Portainer and a healthy VPN before releasing dependents, so the old host startup script is not part of the steady-state design.
- A normal stop/start or process restart of the same VPN container retains its container ID. If all dependents remain healthy, the orchestrator does nothing.
- An update or Compose recreation replaces the VPN container and changes its ID. Existing dependents still refer to the old network namespace and must be recreated against the replacement VPN container.
- `vpn-orchestrator` polls the VPN container ID and dependent health every 15 seconds. On its own startup it immediately reconciles only missing or unhealthy dependents, covering NAS restarts without relying solely on Docker events.
- A changed VPN container ID triggers full parallel stop/start reconciliation because every dependent must join the replacement network namespace. An unhealthy dependent with an unchanged VPN ID gets a 60-second maintenance grace period and then targeted reconciliation only if it remains unhealthy. This prevents an intentional single-stack redeployment from restarting every VPN-dependent service.
- Reconciliation waits for VPN health and then waits for the entire dependent group to become healthy. Portainer remains the deployment authority and recreates each selected container against the current VPN namespace.
- The orchestrator records the new VPN ID only after every dependent is healthy, so a partial failure is retried.
- VPN ID and heartbeat state live under `/Volume1/public/docker-configs/vpn-orchestrator`. The API key is supplied by the `PORTAINER_API_KEY` variable configured on the Portainer stack; never commit its value.
- Mounting `/var/run/docker.sock` gives the orchestrator host-level Docker control. Its image must be trusted, and unrelated behavior or untrusted code must not be added to it.
- The retired watchdog is kept under `_archive/vpn-watchdog` for reference. Do not redeploy it alongside `vpn-orchestrator`.

## Health checks

Add a health check whenever the image contains a usable probe tool and exposes a stable local endpoint. Probe from inside the container and use `localhost` or `127.0.0.1` unless host networking or the application requires the NAS address.

The normal timing is:

```yaml
    healthcheck:
      test: curl --silent --fail http://localhost:<port>/<stable-path>
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 10s
```

- Prefer an actual health/status endpoint; otherwise use a small stable asset.
- Use the probe available in the image. Several images have `wget` but not `curl`.
- Use list form with `CMD` or `CMD-SHELL` when argument boundaries or shell features matter.
- Increase `start_period`, `timeout`, or change retry count only for a demonstrated image-specific need.
- Validate the command inside the actual image when possible; a host-installed executable does not prove it exists in the container.

## Adding a container

### Compose-only deployment invariant

- Every Docker container on the NAS must be defined by a `docker-compose.yml` file committed in this repository and managed through its Portainer Git stack. The repository is the source of truth for all container configuration.
- Never create or replace a NAS container with `docker run`, `docker create`, an uploaded Compose file, Portainer's manual container form, or any other ad hoc mechanism, even as a temporary bootstrap or test.
- A request to "create," "install," "deploy," or "run" a container does not authorize bypassing GitOps. Author and validate the repository Compose file first, then commit, push, and deploy it through Portainer using the established workflow.
- If the repository or Portainer workflow is unavailable, stop and report the blocker. Do not fall back to an unmanaged container.

1. Read the image's official documentation for supported environment variables, persistent paths, required capabilities/devices, ports, and available probe commands.
2. Pick the closest active Compose file by role and image family. LinuxServer.io media managers should follow `radarr`, `sonarr`, or `lidarr`; VPN-independent web apps should follow a comparable bridge service.
3. Create `<service>/docker-compose.yml` with only settings the service needs, following the canonical order.
4. Add WUD and Homepage labels where applicable.
5. Add persistent config and shared-data mounts with the established NAS paths.
6. Configure networking, including both VPN coordination files when applicable.
7. Add and verify a health check.
8. Run `docker compose -f <service>/docker-compose.yml config --quiet` to validate interpolation and syntax. For a VPN-routed change, validate the service, `vpn`, and `vpn-orchestrator` files.
9. Review `git diff --check` and the final diff. Do not deploy, pull images, create NAS directories, or alter running containers unless explicitly asked.

## Changing or removing a container

- Preserve service-specific comments that explain surprising constraints.
- When changing a port, update the published mapping, Homepage widget URL, health check, and any VPN mapping together.
- When renaming a service or container, update Homepage labels and its `vpn-orchestrator` dependency entry where applicable.
- To retire a service, move its directory under `_archive/` rather than deleting it unless deletion was explicitly requested.
- When retiring a VPN-routed service, remove its mapping from `vpn/docker-compose.yml` and its dependency entry from `vpn-orchestrator/docker-compose.yml`.
- Do not edit live data under `/Volume1` or `/Volume2` as part of a repository-only change.

## Scope and validation

Compose syntax validation cannot prove that an image contains the health-check executable, that a tag exists, that ports are free on the NAS, or that credentials are valid. State these deployment assumptions when they were not tested. Never start, stop, recreate, or remove running containers without explicit authorization.
