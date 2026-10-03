# Deployment and Operations

This is the authoritative operator guide for deploying RDC Client.

RDC Client is a **generic optional MCP consumer/bridge**. It is not the MCP server and it is not specific to CyberController. A compatible MCP server may also be accessed directly by n8n, another MCP client, another agent platform, or custom automation without RDC.

## Architecture

```text
ChatGPT
   |
   | Desktop Commander Remote
   v
RDC Client container
   |
   | MCP Streamable HTTP + TLS + bearer token
   v
MCP server
```

For CyberController, the MCP server may be:

```text
egori4/cybercontroller-evidence-service
```

but RDC Client does not contain CyberController log mappings or host mounts.

## 1. Prerequisites

Target host:

- Docker installed/running
- outbound Internet access required by Desktop Commander Remote
- network reachability to the target MCP endpoint
- no host Node.js/npm requirement

The target host pulls a prebuilt image from Docker Hub.

Default image:

```text
egori4/rdc-client:0.1.0
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
CA:      cc-evidence-ca.crt
```

Never provide the MCP server TLS private key to the RDC client.

## 3. Obtain the client deployment files

```bash
git clone https://github.com/egori4/rdc_client.git
cd rdc_client
```

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
MCP_CA_SOURCE=/secure/path/cc-evidence-ca.crt \
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

Contains the Desktop Commander device/session identity.

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

For a CyberController Evidence MCP:

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

For CyberController Evidence MCP 0.2.0, one bearer token is shared by all clients of that Evidence server. Server-side rotation therefore affects RDC, n8n, and any other consumer using that same server.

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
docker pull egori4/rdc-client:0.1.1
```

Then rerun the installer with:

```bash
RDC_CLIENT_IMAGE=egori4/rdc-client:0.1.1 ./install.sh
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

RDC Client uses normal Docker bridge networking. It is not an outbound network sandbox.

Its security boundary relies on:

- no host files/logs
- no Docker socket
- non-root runtime
- empty Linux capability set
- read-only root filesystem
- server-side MCP authorization and guardrails

The MCP server remains responsible for what tools/data the client is allowed to access.
