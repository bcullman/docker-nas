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
`custom.css` is also deployed to the persistent config mount. It arranges the six
sections as three independent desktop columns (1024px and wider):

- Left: Watch, then Media Automation.
- Middle: Media Library, then Smart Home.
- Right: Network, then Server Management.

The `layout` order in `settings.yaml` is column-first. CSS column breaks before
sections three and five keep each pair together without shared grid-row heights.
Keep that order and the CSS breaks in sync if adding or rearranging sections.
Smaller screens use a single column. `useEqualHeights: false` keeps tiles without
widgets compact.

| Group | Tile order |
| --- | --- |
| Watch | Plex, HDHomeRun, Tautulli |
| Media Library | Seerr, SuggestArr, Radarr, Sonarr, Lidarr, Bazarr, Tdarr |
| Media Automation | BitTorrent, Prowlarr, Cleanuparr, FlareSolverr |
| Smart Home | Homebridge, Scrypted |
| Network | AdGuard, Cloudflare Tunnel, NordVPN, My Speed, VPN Orchestrator |
| Server Management | Portainer, What's Up Docker, Scrutiny, PeaNUT, MCPHub |
