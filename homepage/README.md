# Homepage layout

`settings.yaml` is the repository copy of the layout deployed to
`/Volume1/public/docker-configs/homepage/settings.yaml`. The existing config
directory is a persistent bind mount; updating this repository file alone does
not update the live file. Apply it to the mounted configuration and refresh
Homepage after changing the layout.

Docker-discovered tiles use `homepage.group` and `homepage.weight` labels in
each application's Compose file. Weights increase by ten in the desired order.
The two manual tiles remain in the private mounted `services.yaml`:

- HDHomeRun: group `Watch`, weight `20`.
- Portainer: group `Server Management`, weight `10`.

Keep the manual services file private because it contains widget credentials.
The layout uses Homepage's [native nested groups](https://gethomepage.dev/configs/settings/#nested-groups)
with three parent groups whose headers are hidden:

- Left Column: Watch, then Media Automation.
- Middle Column: Media Library, then Smart Home.
- Right Column: Network, then Server Management.

The private `services.yaml` mirrors this hierarchy. Preserve the existing manual
HDHomeRun and Portainer definitions under their nested groups. Empty lists let
Docker discovery populate the other groups:

```yaml
- Left Column:
    - Watch:
        # Existing HDHomeRun entry goes here.
    - Media Automation: []
- Middle Column:
    - Media Library: []
    - Smart Home: []
- Right Column:
    - Network: []
    - Server Management:
        # Existing Portainer entry goes here.
```

Update both files together when changing the nesting. Docker labels continue to
use the six visible section names. Homepage handles responsive sizing natively;
`useEqualHeights: false` keeps tiles without widgets compact. No custom CSS or
JavaScript is required. Keep the mounted `custom.css` empty to remove the previous
layout override.

| Group | Tile order |
| --- | --- |
| Watch | Plex, HDHomeRun, Tautulli |
| Media Library | Seerr, SuggestArr, Radarr, Sonarr, Lidarr, Bazarr, Tdarr |
| Media Automation | BitTorrent, Prowlarr, Cleanuparr, FlareSolverr |
| Smart Home | Homebridge, Scrypted |
| Network | AdGuard, Cloudflare Tunnel, NordVPN, My Speed, VPN Orchestrator |
| Server Management | Portainer, What's Up Docker, Scrutiny, PeaNUT, MCPHub |
