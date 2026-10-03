# RDC Client

A hardened Remote Desktop Commander container with a small generic MCP Streamable HTTP client.

The project is intentionally **client-only**. It does not read CyberController logs, mount host filesystems, or implement product-specific evidence logic. Those responsibilities belong to the MCP server it connects to.

## Architecture

```text
ChatGPT
   |
   v
Desktop Commander Remote
   |
   v
RDC Client container
   |
   | mcpctl (MCP Streamable HTTP)
   v
Remote MCP server
```

## Included commands

```bash
mcpctl health
mcpctl tools
mcpctl call <tool-name> '{"argument":"value"}'
```

Configuration:

- `MCP_URL` - MCP Streamable HTTP endpoint
- `MCP_BEARER_TOKEN_FILE` - recommended bearer token file
- `MCP_BEARER_TOKEN` - optional environment fallback
- `MCP_CA_CERT_FILE` - optional CA certificate path

## Container boundary

The recommended deployment runs:

- non-root UID/GID 10001
- read-only root filesystem
- all Linux capabilities dropped
- `no-new-privileges`
- no Docker socket
- no host filesystem mounts
- no host namespace sharing
- no published inbound ports
- bounded CPU, memory, PIDs, file descriptors and tmpfs
- persistent Desktop Commander device state only
- read-only MCP secret/CA volume

See `docs/SECURITY.md` and `docs/DEPLOYMENT.md`.

## Build

Build on a workstation or CI runner, not on the target server:

```bash
npm test
docker build --pull --no-cache -t rdc-client:0.1.0 .
```

Desktop Commander is resolved from `@wonderwhy-er/desktop-commander@latest` at image build time unless `DESKTOP_COMMANDER_VERSION` is explicitly supplied.

## Public-repo rule

Never commit:

- bearer tokens
- private keys
- customer certificates containing private keys
- environment-specific credentials
- Remote Desktop Commander device state
