# Headless Playwright

Dedicated browser for general public browsing through MCPHub. The Mac's separate
headed Playwright connector remains the option for interactive website login.

Deploy this Compose file as a Portainer Git stack after MCPHub: it joins the
existing `mcphub_default` network. Register a Streamable HTTP connector named
`playwright-headless` at `http://playwright-headless:8931/mcp` in MCPHub.
No browser-control port is published to the LAN or Internet.

The official Microsoft image is pinned to `v0.0.82`. Its entrypoint runs headless
Chromium with `--no-sandbox`; the dedicated container has no Docker socket, host
filesystem mounts, or application credentials. `--isolated` keeps the browser
profile temporary. This is not a read-only tool: browser interactions can submit
forms or change websites. Use it for public browsing by default and keep login
sessions in the Mac connector. Other containers on the shared network can reach
the endpoint; MCPHub authentication protects access through the hub.

The health check verifies the listener using Node, which is included in the image.
Browser navigation must also be tested after deployment or image upgrades.

Upstream: <https://github.com/microsoft/playwright-mcp>
