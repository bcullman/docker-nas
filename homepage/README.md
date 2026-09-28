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
Full-width row layouts keep each category together and avoid gaps beside long groups.
`useEqualHeights: false` keeps tiles without widgets compact. Sections use two to four
columns on desktop and collapse responsively on smaller screens.

| Group | Tile order |
| --- | --- |
| Watch | Plex, HDHomeRun, Tautulli |
| Media Library | Seerr, SuggestArr, Radarr, Sonarr, Lidarr, Bazarr, Tdarr |
| Media Automation | BitTorrent, Prowlarr, Cleanuparr, FlareSolverr |
| Smart Home | Homebridge, Scrypted |
| Network | AdGuard, Cloudflare Tunnel, NordVPN, My Speed, VPN Orchestrator |
| Server Management | Portainer, What's Up Docker, Scrutiny, PeaNUT, MCPHub |
