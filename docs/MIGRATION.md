# Rename migration: 0.1.0 to 0.2.0

The GitHub repository is now `egori4/cybercontroller-rdc-client` (formerly `egori4/rdc_client`). The Docker Hub image is now `egori4/cybercontroller-rdc-client:0.2.0` (formerly `egori4/rdc-client`). Git history is retained. Docker Hub image names do not follow GitHub redirects.

## Existing working copy

```bash
git remote set-url origin https://github.com/egori4/cybercontroller-rdc-client.git
git pull --ff-only
```

Renaming the local checkout directory is optional. On the maintainer's development machine it was renamed to match the repository.

## Existing installation

Do not remove either volume. Defaults intentionally remain:

- container `rdc-client`
- pairing volume `rdc-client-state`
- MCP credential/trust volume `rdc-client-secrets`
- `RDC_CLIENT_IMAGE`, `/run/rdc-client`, and `/opt/rdc-client` remain compatible.

Record the existing device name and MCP endpoint without printing credentials:

```bash
docker inspect rdc-client --format '{{.Config.Hostname}}'
# Retrieve the MCP URL from your deployment record; do not dump all environment values.
docker pull egori4/cybercontroller-rdc-client:0.2.0
RDC_CLIENT_IMAGE=egori4/cybercontroller-rdc-client:0.2.0 ./install.sh
```

Supply the same device name and MCP URL; accept recreation of the existing container. The installer reuses the existing state, token and CA. If custom container/volume names were used, set `CONTAINER_NAME`, `STATE_VOLUME`, and `SECRETS_VOLUME` to those same values when invoking the installer and rotation scripts.

Verify with `scripts/verify-container.sh rdc-client`, then start it and run `docker exec rdc-client mcpctl health`.

This migration changes names and pins the upstream RDC version; it does not add host permissions or change the MCP server. Do not migrate or share pairing volumes between this restricted client and the privileged host-admin project.
