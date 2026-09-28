# MCPHub

The dashboard and MCP endpoint share host port `13000`; the aggregate MCP endpoint is `/mcp`.
Set `MCPHUB_ADMIN_PASSWORD` and `MCPHUB_JWT_SECRET` in the Portainer stack before deployment.
Connector configuration is managed in MCPHub and persisted in the mounted data directory.

## Remote access

The Mac Codex client uses `https://mcphub.bullman.net/mcp` through the existing
Cloudflare Tunnel. A dedicated Cloudflare Access application, `MCPHub remote MCP`,
covers `mcphub.bullman.net/mcp`. Its Service Auth policy accepts only the
`Codex Mac - MCPHub` service token; a separate allow policy preserves the owner's
browser access. The wildcard application protecting other subdomains is unchanged.

The client sends `CF-Access-Client-Id`, `CF-Access-Client-Secret`, and the existing
MCPHub `Authorization: Bearer ...` header. Values are stored privately in the Mac's
Codex configuration with file permissions `0600`, with a private backup of the prior
configuration. Never copy these values into this repository.

The Cloudflare service token expires on 2027-09-19 UTC. Renew or rotate it in
Cloudflare Access and update the client's headers before expiration. Revoking this
token disables this client's service-token access through Cloudflare.

Verified through the public HTTPS endpoint: MCP initialization, discovery of 559 tools,
and a read-only Radarr status query. Omitting Cloudflare credentials produced a login
redirect; omitting the MCPHub bearer key produced HTTP 401. Testing used the public
route from the Mac, not a physically separate outside network. Reload VS Code to load
the updated client configuration.

## Connector inventory

Verified against the live deployment on 2026-09-18. Credentials remain in MCPHub's
persistent data; no credential values belong in this file. The existing Codex client key
discovers all connected servers through `/mcp` (556 tools across 14 connected servers).
Reload the VS Code window if its current session has cached the earlier tool list.

| Service | Connector / pinned release | Read-only verification |
| --- | --- | --- |
| Radarr | `@orellbuehler/radarr-mcp@0.1.0` | `get_system_status`, `list_movies` |
| Sonarr | `@orellbuehler/sonarr-mcp@0.1.0` | `get_system_status`, `list_series` |
| Tdarr | [tdarr-mcp](https://github.com/OrellBuehler/tdarr-mcp), `0.1.0` | `get_status` |
| Homebridge | [homebridge-mcp-server](https://github.com/mp-consulting/homebridge-mcp-server), `1.1.0` | `get_homebridge_status` |
| AdGuard Home | [mcp-adguard-home](https://github.com/Samik081/mcp-adguard-home), `0.9.2` | `global_get_status` |
| Lidarr | [mcp-arr-server](https://github.com/aplaceforallmystuff/mcp-arr), `1.7.3` | `arr_status` |
| Prowlarr | Same package, separate service configuration | `arr_status` |
| Plex | [plex-mcp-server](https://github.com/vladimir-tutin/plex-mcp-server), `1.1.7` | `library_list` |
| Tautulli | [mcp-tautulli](https://github.com/lodordev/mcp-tautulli), `1.3.1` | `tautulli_activity` |
| Bazarr | [mcp-mediastack](https://github.com/aderaaij/mcp-mediastack), commit below | `get_bazarr_status` |
| Seerr | Same source, separate service configuration | `get_seerr_status` |
| CleanUpArr | Same source, separate service configuration | Status and events |
| qBittorrent | [aitorrent](https://github.com/konsumer/aitorrent), `0.0.1`, `aitorrent-qbt mcp` | `qbt_get_transfer_info` |
| Scrypted | [scrypted-mcp plugin](https://github.com/sv-tools/scrypted-mcp-plugin), installed `1.0.10` | `list_plugins` |
| Spotify | [spotify-mcp](https://github.com/llyfn/spotify-mcp), `mcp-server-spotify==0.2.0`, Python 3.12 and `mcp<2` | `get_my_playlists`, `get_saved_tracks`; 38 read tools enabled and 21 write tools disabled, verified 2026-09-19 |
| Firecrawl | Official hosted `https://mcp.firecrawl.dev/v2/mcp`, keyless tier | 3 tools; `firecrawl_search` and `firecrawl_scrape` verified 2026-09-19 |
| Context7 | Official hosted `https://mcp.context7.com/mcp`, basic access without an API key | 2 tools; `resolve-library-id` and `query-docs` verified with pytest on 2026-09-19 |
| Playwright headless | Official Microsoft `mcr.microsoft.com/playwright/mcp:v0.0.82`, separate Git stack | 25 tools; navigation and page snapshot verified 2026-09-20 via private `http://playwright-headless:8931/mcp` |

Node connectors run through `npx` inside MCPHub. Python connectors run through `uvx`.
Radarr uses `RADARR_URL` and `RADARR_API_KEY`; Sonarr uses `SONARR_URL` and
`SONARR_API_KEY`, configured privately in MCPHub. Both expose read and write tools;
verification used only read operations and did not change either library.

Scrypted uses its installed plugin's HTTP endpoint and MCPHub-managed OAuth credentials;
it does not need a separate container. The endpoint path is
`/endpoint/scrypted-mcp/public/mcp` on the existing Scrypted server.

The media-stack source is pinned to `3ee42ce4b8650de2baf0fdd8b9b3ff1aeae3f332`:

```text
uvx --with mcp<2 --from git+https://github.com/aderaaij/mcp-mediastack.git@3ee42ce4b8650de2baf0fdd8b9b3ff1aeae3f332 mcp-mediastack
```

This is an argument list, not an unquoted shell command: quote `mcp<2` if entering it
in a shell. Each instance sets `NAS_HOST`, `ENABLED_SERVICES` to its single service,
and only that service's credentials. CleanUpArr additionally sets `CLEANUPARR_PORT`.

### Compatibility findings

- Media-stack's unconstrained MCP dependency installed SDK 2, whose removal of
  `mcp.server.fastmcp` prevented startup. Adding `--with mcp<2` resolved it. The qBittorrent
  launcher uses the same constraint. Preserve it until the upstream code supports SDK 2.
- The deployed qBittorrent returns HTTP 204 with a session cookie after successful login.
  Media-stack incorrectly requires an `Ok.` response body. The `aitorrent` connector's
  maintained qBittorrent API client authenticated successfully instead.
- The current `@cyanheads/seerr-mcp-server` release requires Node 24; the verified
  media-stack connector works in this MCPHub runtime without a Node upgrade.
- Check tool response contents as well as `isError`: media-stack's qBittorrent login
  failure was returned as ordinary text with `isError: false`.
- Cloudflare rejects MCPHub's fallback `openid` scope. Configure explicit OAuth scopes:
  `user:read`, `offline_access`, `account:read`, `teams-connector-cloudflared.read`, and
  `teams-connector-cloudflared.monitoring`. These request identity, token refresh, and
  read-only tunnel monitoring access; the user completes Cloudflare's consent screen.
- For this MCPHub version, setting `oauth.redirectUri` alone did not change the generated
  callback from `http://localhost:3000/oauth/callback`. Also set
  `oauth.dynamicRegistration.metadata.redirect_uris` to the public MCPHub
  `/oauth/callback` URL and `metadata.scope` to the space-separated scopes. Clear the
  stale registration with `POST /api/servers/cloudflare/oauth/disconnect` before saving
  the corrected config. Verified the new authorization URL reaches HTTP 200 consent
  UI without the invalid-scope error; account authorization still requires user sign-in.

### Pending and unavailable integrations

| Service | Finding |
| --- | --- |
| GitHub | Official hosted server connected on 2026-09-19 at `https://api.githubcopilot.com/mcp/readonly`, with `X-MCP-Readonly: true` and toolsets `repos,issues,pull_requests,actions`. Verified 25 tools, all annotated read-only, and a successful `list_commits` call against this repository. Token permission scope was not independently audited. |
| Cloudflare tunnel | [Official Cloudflare MCP](https://github.com/cloudflare/mcp) is connected through OAuth at `https://mcp.cloudflare.com/mcp`. Account access and Access policy operations have been verified. |
| Homepage | [Native MCP endpoint](https://gethomepage.dev/configs/mcp/) requires enabling it and a private `HOMEPAGE_MCP_TOKEN`. Compose change is prepared and validated; deployment approval is pending. Default endpoint access remains read-only. |
| WUD | No suitable standalone connector found; Homarr integration would require an additional application. Container was restarting during inventory. |
| Scrutiny | Found a generic reachability check, but no suitable connector for this deployment's disk/SMART data. |
| PeaNUT, MySpeed, SuggestArr | No suitable published application connector found. |
| NordVPN container | Available VPN MCP projects target a local CLI or Gluetun, not this deployed container's remote API. |
| VPN orchestrator | Repository-specific service without an application MCP connector. |
| MCPHub | Provides the aggregate endpoint itself. |

Portainer's current official MCP targets versions 2.41 and newer, while this deployment
runs 2.24.0. It was not added as an unverified substitute for the missing app connectors.

For GitHub credential renewal, create a dedicated fine-grained token restricted to selected repositories,
with Contents, Issues, Pull requests, and Actions permissions set to read-only (Metadata
read access is automatic). Set an expiration. Add it privately to the connector's headers
as `Authorization: Bearer <token>`, preserve the existing headers, then enable the connector.
Do not reuse deployment or release credentials. Verify tool discovery and a repository read
before marking it connected. The read-only endpoint restricts tools; the token permissions
independently restrict access. See the [official server documentation](https://github.com/github/github-mcp-server/blob/main/docs/remote-server.md).

To finish Homepage after deployment authorization: create a private stack variable,
preserve all existing Portainer environment entries, commit/push the Compose change,
redeploy its Git stack, and register `/api/mcp` with a bearer token in MCPHub. Verify
`list_config_files` without printing configuration file contents or service credentials.

## Tool-call API compatibility

The deployed MCPHub API accepts `POST /api/tools/call/radarr-<tool_name>` with the tool's
arguments directly in the JSON body and returns the MCP result directly. For example,
`/api/tools/call/radarr-list_movies` accepts `{"has_file":false,"limit":2}`.

Current upstream source instead documents a server-name route with a `toolName` and
`arguments` wrapper. Using that form on this deployment returned `Tool not available: radarr`;
wrapping the arguments on the tool-name route silently omitted the intended filters.
Verify the deployed API shape when upgrading, and check returned data rather than relying
only on HTTP success. Authentication uses the dashboard login token in `x-auth-token`.

## Spotify authentication

Spotify runs through `uvx` inside MCPHub. The app client ID and secret are stored
privately in its connector environment. Initial authorization completes using a
state-validated callback on the Mac at `http://127.0.0.1:8888/callback`; tokens are
transferred privately into `/app/data/spotify/credentials.json` (directory `0700`,
file `0600`) on MCPHub's existing persistent mount. No container restart was needed.

The launcher overrides both the config and auth modules' credential paths because
importing the package loads the auth module before the config override. It also
restricts both modules' `ALL_SCOPES` to the approved read-only scopes. The verified
grant includes library, playlists, followed artists, top items, playback state and
listening history reads; it contains no modification scopes. Playback, playlist,
library and follow write tools are separately disabled in MCPHub.

The built-in callback runs inside the connector's host; for a NAS deployment,
reauthorization must again use a callback reachable from the user's browser, such
as the Mac helper flow. Do not broaden scopes during renewal. Token refresh uses
the existing grant and persists refreshed credentials to the same mounted path.

On this deployed MCPHub version, updating `config.enabled` through the server edit
endpoint did not start the disabled connector. Use
`POST /api/servers/spotify/toggle` with `{"enabled":true}`, then verify connected
status and tool calls. Saving configuration alone is not a connection test.

## Research and documentation connectors

Firecrawl and Context7 use hosted Streamable HTTP endpoints through MCPHub. Neither
required credentials for the verified basic queries; rate limits apply. No paid
subscription or private repository indexing was configured. Firecrawl's keyless
endpoint exposes search, scrape, and parse; only search and scrape were tested.
Context7 resolved pytest and returned documentation for its `tmp_path` fixture.

Queries and requested page content are processed by the respective external
services. Use public research and documentation questions; keep credentials and
private source content out of query arguments. If higher limits are needed, add
a dedicated credential privately in MCPHub, not this repository.
