# FlareSolverr

Cloudflare challenge helper for Prowlarr, deployed as Portainer Git stack 69.
It shares `container:vpn` with Prowlarr so both use the same outbound IP.
The VPN orchestrator recreates it when the VPN network namespace changes.

Prowlarr connects to `http://localhost:8191/` using a FlareSolverr indexer proxy.
Assign the `flaresolverr` tag to both the proxy and each indexer that needs it.
A proxy without matching tags is not used. Test the proxy and the indexer
separately: a healthy helper does not guarantee a Cloudflare challenge can be solved.

Homepage discovers its service tile through Docker labels. FlareSolverr has no
management dashboard or native Homepage widget, so the tile has no public link.
Port 8191 is published on the NAS LAN address by the VPN Compose file for local
diagnostics. Do not add a Cloudflare Tunnel route to this unauthenticated API.

The service is stateless; browser sessions and challenge cookies are temporary.
The image includes its own init process and curl for the `/health` probe. Startup
allows 60 seconds for the browser self-test.
