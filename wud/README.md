# What's Up Docker

WUD 9 requires an administrator before it will start. The Git stack supplies
`WUD_AUTH_ADMIN_USER=admin` and takes `WUD_AUTH_ADMIN_PASSWORD` from the private
Portainer stack variable `WUD_ADMIN_PASSWORD`. Retrieve the generated password
from the stack's environment variables; never commit its value.

The database is persisted at `/Volume1/public/docker-configs/wud`, mounted at
`/store`. After initial provisioning, users and passwords are managed in WUD.
Changing the bootstrap variable should not be treated as a database password reset.

The image is pinned to `9.1.0`. Review migration requirements before changing the
version. The image includes a health check against `/health`.

## Startup repair, 2026-09-27

The previous unpinned deployment reached WUD 9.1.0 with no administrator and
restarted repeatedly. The LAN endpoint refused connections while Cloudflare
Access still returned its normal sign-in redirect.

The stopped container's store was backed up privately before replacement. It
contained no users, containers, monitoring history, or custom configurations.
The repair created a fresh persistent store and provisioned the administrator
through Portainer Git stack 44. Verification checks the health endpoint, login
page, authenticated container API, restart count, and persistent mount.

Public URL: <https://wud.bullman.net>. LAN URL: <http://192.168.0.250:3001>.
Cloudflare Access and WUD authentication are separate login layers. API clients,
including dashboard widgets, also need WUD authentication under version 9.

References: [Authentication](https://getwud.app/docs/configuration/authentications/),
[Storage](https://getwud.app/docs/configuration/storage/).
