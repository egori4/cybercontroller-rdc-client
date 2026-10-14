# Deployment and Operations

This is the authoritative operator guide for deploying CyberController RDC Client.

CyberController RDC Client is the **restricted optional MCP consumer/bridge for CyberController MCP**. It is not the MCP server. Its MCP transport is generic, but this repository documents the CyberController deployment role. A compatible MCP server may also be accessed directly by n8n, another MCP client, another agent platform, or custom automation without RDC.

## Architecture

```text
ChatGPT
   |
   | Desktop Commander Remote
   v
CyberController RDC Client container
   |
   | MCP Streamable HTTP + TLS + bearer token
   v
MCP server
```

For CyberController, the MCP server may be:

```text
egori4/cybercontroller-mcp
```

but CyberController RDC Client does not contain CyberController log mappings or host mounts.

## 1. Prerequisites

Target host:

- Docker installed/running
- outbound Internet access required by Desktop Commander Remote
- network reachability to the target MCP endpoint
- no host Node.js/npm requirement

The target host pulls a prebuilt image from Docker Hub.

Default image:

```text
egori4/cybercontroller-rdc-client:0.3.0
```

## 2. What the MCP server operator provides

For an authenticated TLS MCP server, the RDC operator needs:

1. MCP URL
2. bearer token
3. CA/public certificate only if normal system trust does not already trust the server

Example:

```text
MCP URL: https://10.10.20.15:8443/mcp
Token:   <secret>
CA:      cybercontroller-mcp-ca.crt
```

Never provide the MCP server TLS private key to the RDC client.

## 3. Obtain the client deployment files

Keep CyberController add-on scripts under `/opt/radware/storage/scripts`. On a system where this is the first locally installed tool, the `scripts` directory may not exist yet, so create it first:

```bash
mkdir -p /opt/radware/storage/scripts
cd /opt/radware/storage/scripts
git clone https://github.com/egori4/cybercontroller-rdc-client.git
cd cybercontroller-rdc-client
```

The expected repository path on CyberController is therefore:

```text
/opt/radware/storage/scripts/cybercontroller-rdc-client
```

All relative commands in this guide such as `./install.sh` and `./scripts/...` assume you are running them from that repository root unless the command explicitly says otherwise.

The repository supplies the installer. The application image is pulled from Docker Hub.

## 4. Install

Run:

```bash
./install.sh
```

Typical prompts:

```text
RDC device name [rdc-<host>]:
MCP URL (for example https://server:8443/mcp):
CA certificate path (leave blank if normal public PKI):
MCP bearer token:
Start now for RDC pairing? [Y/n]:
```

The bearer-token prompt is hidden.

If a private/self-signed CA file is required, enter its local path when prompted.

### Noninteractive example

```bash
RDC_DEVICE_NAME=customer-a-cc01 \
MCP_URL=https://10.10.20.15:8443/mcp \
MCP_CA_SOURCE=/secure/path/cybercontroller-mcp-ca.crt \
START_NOW=n \
./install.sh
```

For noninteractive token injection, `MCP_BEARER_TOKEN` is supported, but interactive hidden entry or an approved secret-management workflow is preferable.

## 5. Docker objects created

Default objects:

```text
container: rdc-client
volume:    rdc-client-state
volume:    rdc-client-secrets
```

### rdc-client-state

Mounted at:

```text
/home/rdc/.desktop-commander-device
```

Contains the Desktop Commander device/session identity and, when `RDC_AUTO_UPDATE=true`, versioned downloaded runtimes under `runtime/`.

This is sensitive and unique to the paired RDC device.

### rdc-client-secrets

Mounted read-only at runtime:

```text
/run/rdc-client
```

Contains:

```text
token
ca.crt    # only when needed
```

The bearer token is the MCP-server credential.

The CA certificate is public trust material, not a private key.

## 6. First Desktop Commander pairing

Start attached:

```bash
docker start -ai rdc-client
```

Desktop Commander prints a device-verification URL and code.

Example:

```text
https://mcp.desktopcommander.app/device/verify?user_code=ABCD-EFGH
ABCD-EFGH
```

The operator opens the URL on their normal browser and signs into/approves the intended Desktop Commander account.

After successful pairing, the RDC device state is persisted in `rdc-client-state`.

Future container starts normally reuse that device identity.

## 7. Verify MCP access

When the container is running:

```bash
docker exec rdc-client mcpctl health
docker exec rdc-client mcpctl tools
```

For a CyberController MCP:

```bash
docker exec rdc-client mcpctl call get_catalog
```

Then test a bounded real query using the MCP server's documented tool schema.

## 8. Verify the container boundary

```bash
./scripts/verify-container.sh rdc-client
```

Expected properties include:

- non-root UID 10001
- read-only rootfs
- all capabilities dropped
- no-new-privileges
- no Docker socket
- no host-root mount
- no published ports
- 0.5 CPU / 512 MiB / 96 PID limits
- bounded Docker logs

Some older hosts cannot enforce Docker swap accounting. The installer warns when that happens; the RAM limit still remains configured.

## 9. Normal lifecycle

Enable RDC access:

```bash
docker start rdc-client
```

Disable RDC access:

```bash
docker stop rdc-client
```

Stopping the RDC client does not stop the MCP server. Other MCP consumers may continue operating.

## 9A. Update the RDC client

### One-time image upgrade from 0.2.0 to 0.3.0

Version 0.3.0 introduces opt-in, **startup-only** upstream Desktop Commander updates. Existing containers stay unchanged until an operator upgrades the Docker image. **Run from independent SSH/host access**, not through the RDC session that is about to be replaced. Use the actual existing Git checkout location (often `/opt/radware/storage/scripts/cybercontroller-rdc-client` in CyberController installations).

1. Before the first upgrade, **back up the paired state and secret volumes** securely, while RDC is stopped. The state holds the Remote device credential; secrets hold the MCP bearer token. Example for default volume names:

```bash
docker stop rdc-client
umask 077
mkdir -p "$HOME/rdc-client-backup"
docker run --rm --network none --user 0:0 \
  --mount type=volume,src=rdc-client-state,dst=/state,readonly \
  --entrypoint tar egori4/cybercontroller-rdc-client:0.2.0 \
  -C /state -czf - . > "$HOME/rdc-client-backup/state.tar.gz"
docker run --rm --network none --user 0:0 \
  --mount type=volume,src=rdc-client-secrets,dst=/secrets,readonly \
  --entrypoint tar egori4/cybercontroller-rdc-client:0.2.0 \
  -C /secrets -czf - . > "$HOME/rdc-client-backup/secrets.tar.gz"
```

Keep these credential-bearing archives private and off the host in an approved secure backup location. Adjust the volume names for customized deployments. Stopping the container for backup means `update.sh` will preserve its stopped state; start it explicitly afterward.

2. Upgrade using the new scripts and enable automatic RDC runtime updates:

```bash
cd /opt/radware/storage/scripts/cybercontroller-rdc-client
git pull --ff-only origin main
docker pull egori4/cybercontroller-rdc-client:0.3.0
RDC_AUTO_UPDATE=true ./update.sh egori4/cybercontroller-rdc-client:0.3.0
docker start rdc-client           # if previously stopped for backup
```

`update.sh` checks that the old and new images are labeled as restricted CyberController RDC clients **before stopping the existing container**. It retains the previous container under a timestamped `rdc-client-rollback-...` name. The replacement reuses the existing device name, MCP URL, `rdc-client-state` pairing volume, read-only `rdc-client-secrets` token/CA volume, and the old running/stopped state. An initial installation of a new image is not an upstream npm update.

For later image upgrades, `RDC_AUTO_UPDATE` is preserved automatically unless explicitly overridden. An old 0.2.0 container lacking the option defaults to `false`. Do not run `./install.sh` to replace a working instance; use `./update.sh` to retain a rollback container. The image-update script recreates the **documented standard restricted configuration** and does not reproduce undocumented manual Docker overrides, environment additions or custom mounts.

### How automatic upstream RDC updates work

- **Off by default.** Enable on a new `install.sh` with `RDC_AUTO_UPDATE=true`, or on an existing client through `update.sh` as above.
- On every **container start/restart**, check npm's stable `latest` dist-tag (up to 12 seconds). Only versions matching numeric `MAJOR.MINOR.PATCH` are accepted, and only if newer than the current cached/bundled version.
- Download new packages as **UID 10001** into a temporary directory under `rdc-client-state/runtime/versions` (up to 300 seconds), using npm cache there rather than the 8 MiB writable npm tmpfs. Run `desktop-commander remote --help` as a small validation check (up to 20 seconds), then atomically select the version. npm download cache is discarded afterward to limit growth.
- With npm offline or a failed install/validation, use the **last validated cached runtime** or image-bundled **0.2.52**. It does not download or restart while RDC is already running. Switching runtime version does not change the Docker image version/tag.
- Versioned downloaded runtimes consume persistent disk space: the tested 0.3.0 install occupied approximately **255 MiB**. Older cached versions remain for fallback and can accumulate; monitor disk use and remove unnecessary older versions only during maintenance with the container stopped. The 512 MiB container RAM limit is not a volume disk quota.
- There is **no post-start remote-connection health check or automatic rollback from failures after the new RDC process launches**. An incompatible upstream release can require an image refresh (Node.js/system libraries). Take backup before the first upgrade.
- The updater does not add privileges, mounts, a network, or another volume; the runtime cache is stored inside the existing sensitive pairing volume. The restricted client still can read its mounted MCP bearer token. Review [Security](SECURITY.md) before enabling automatic npm code execution.

### Verification

```bash
./scripts/verify-container.sh rdc-client
docker inspect rdc-client --format '{{.Config.Image}}'
docker inspect rdc-client --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^RDC_AUTO_UPDATE='
docker logs --tail 50 rdc-client
docker exec rdc-client mcpctl health
docker exec rdc-client mcpctl tools
```

Expected logs show `RDC runtime: activated 0.3.0` on initial download or `RDC runtime: starting 0.3.0` when using the cache (actual version may be newer). Confirm the device appears online in the Desktop Commander dashboard and perform a real bounded tool call. A passing npm CLI `--help` check alone does not prove that remote pairing/MCP connectivity works.

Subsequent stable RDC releases need **only an explicit `docker restart rdc-client`**, not a rebuilt image, provided the upstream runtime stays compatible. The default Docker restart policy remains `no`.

### Disable automatic updates or manually roll back

To disable upstream updates and force the bundled 0.2.52 runtime, run from independent host access:

```bash
RDC_AUTO_UPDATE=false ./update.sh egori4/cybercontroller-rdc-client:0.3.0
```

If the running client is broken and the old container is still available, restore the timestamped old container (substitute its actual name):

```bash
docker stop rdc-client
docker rm rdc-client
docker rename rdc-client-rollback-YYYYMMDDTHHMMSSZ rdc-client
docker start rdc-client
```

Never start both with the same paired state volume. Stop the restored instance instead of starting it if the previous deployment was intentionally offline. Older versions may not understand changes written to shared device state by a newer upstream runtime; retain the pre-upgrade state backup. Once verified, remove unnecessary **stopped** rollback containers using `docker rm <backup-container-name>` without deleting the volumes.

## 10. Credential model

Two independent credentials exist:

```text
Desktop Commander identity
  -> rdc-client-state
  -> identifies/authorizes the RDC device/account

MCP bearer token
  -> rdc-client-secrets/token
  -> authorizes this client to the configured MCP server
```

Revoking one does not automatically revoke the other.

## 11. Replace / rotate the MCP token

If the MCP server rotates its token:

```bash
./scripts/set-token.sh
```

Paste the new token when prompted.

Then:

```bash
docker restart rdc-client
docker exec rdc-client mcpctl health
```

For CyberController MCP 0.2.0, one bearer token is shared by all clients of that CyberController MCP server. Server-side rotation therefore affects RDC, n8n, and any other consumer using that same server.

## 12. Replace the CA certificate

```bash
./scripts/set-ca.sh /path/to/new-ca.crt
```

If the existing container already has `NODE_EXTRA_CA_CERTS=/run/rdc-client/ca.crt`, restart it.

If the client was originally installed without a custom CA and now needs one, rerun `./install.sh` so the container is recreated with the CA environment setting.

Never copy a server private key into the RDC client.

## 13. Revoke RDC access

### Temporary revocation

```bash
docker stop rdc-client
```

The RDC device becomes offline while preserving pairing.

### Replace the paired RDC identity/account

Stop and remove the client:

```bash
docker stop rdc-client
docker rm rdc-client
```

Destroy the old RDC device state:

```bash
docker volume rm rdc-client-state
```

Then run `./install.sh` again and pair using the new Desktop Commander account.

The MCP secret volume can be preserved if the new RDC identity is still authorized to use the same MCP credential.

Also revoke/remove the old device from the Desktop Commander account using Desktop Commander's own device-management controls when permanent revocation is required.

## 14. Multiple CyberControllers / MCP servers

Separate hosts can use the same default local Docker object names because volumes/containers are host-local.

Give every RDC device a globally recognizable device name, for example:

```text
customer-a-prod-cc01
customer-a-dr-cc01
```

Each host has its own state/secrets volumes and can point to a different MCP endpoint/token.

## 15. Multiple RDC accounts on one Docker host

Use unique Docker objects for each identity.

Alice:

```bash
CONTAINER_NAME=rdc-client-alice \
STATE_VOLUME=rdc-client-state-alice \
SECRETS_VOLUME=rdc-client-secrets-alice \
RDC_DEVICE_NAME=customer-a-cc01-alice \
MCP_URL=https://10.10.20.15:8443/mcp \
./install.sh
```

Bob:

```bash
CONTAINER_NAME=rdc-client-bob \
STATE_VOLUME=rdc-client-state-bob \
SECRETS_VOLUME=rdc-client-secrets-bob \
RDC_DEVICE_NAME=customer-a-cc01-bob \
MCP_URL=https://10.10.20.15:8443/mcp \
./install.sh
```

Their Desktop Commander device identities are independent.

If the target MCP server supports only one bearer token, their separate secrets volumes may currently contain the same server token.

## 16. Upgrade / replace the client image

Example:

```bash
docker pull egori4/cybercontroller-rdc-client:0.2.1
```

Then rerun the installer with:

```bash
RDC_CLIENT_IMAGE=egori4/cybercontroller-rdc-client:0.2.1 ./install.sh
```

When prompted, recreate the existing container.

The installer reuses:

- `rdc-client-state`
- `rdc-client-secrets`

Therefore normal image replacement preserves both RDC pairing and MCP credential/trust state.

Use explicit release tags or immutable image digests in production rather than `latest`.

## 17. Uninstall

Remove only the disposable client container:

```bash
docker rm -f rdc-client
```

Preserve volumes if you expect to reinstall.

Complete removal:

```bash
docker rm -f rdc-client 2>/dev/null || true
docker volume rm rdc-client-state
docker volume rm rdc-client-secrets
```

Removing `rdc-client-state` removes local pairing state.

Removing `rdc-client-secrets` removes the local MCP token/CA copy.

For permanent RDC revocation, also remove/revoke the device in the Desktop Commander account.

## 18. Security note

CyberController RDC Client uses normal Docker bridge networking. It is not an outbound network sandbox.

Its security boundary relies on:

- no host files/logs
- no Docker socket
- non-root runtime
- empty Linux capability set
- read-only root filesystem
- server-side MCP authorization and guardrails

The MCP server remains responsible for what tools/data the client is allowed to access.

## Repository rename

Version 0.2.0 keeps the legacy Docker object names (`rdc-client`, `rdc-client-state`, `rdc-client-secrets`) and internal paths intentionally so upgrades preserve pairing and tokens. The GitHub repository and Docker Hub image now use `cybercontroller-rdc-client`. Follow [MIGRATION.md](MIGRATION.md) rather than creating fresh credential volumes.

Host administration is a different project: [rdc-host-admin](https://github.com/egori4/rdc-host-admin). It is not required by this client or by the MCP server.
