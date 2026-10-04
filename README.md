# CyberController RDC Client

The restricted Remote Desktop Commander access option for **CyberController MCP**, with a small MCP Streamable HTTP command-line client. It deliberately has no direct host-administration access.

For generic root-equivalent host administration, use the separate [rdc-host-admin](https://github.com/egori4/rdc-host-admin) project. Never add a privileged mode, host-root mount, or Docker socket to this image.

The transport remains generic; the project name describes its supported deployment role, not a CyberController-specific protocol.

CyberController RDC Client is an **optional bridge/consumer**, not an MCP server and not the only way to access one. An MCP server may instead be used directly by n8n, another MCP client, another agent platform, or custom automation.

## Architecture

```text
ChatGPT
   |
   v
Desktop Commander Remote
   |
   v
CyberController RDC Client container
   |
   | mcpctl / MCP Streamable HTTP
   v
Remote MCP server
```

The project is intentionally client-only. It does not mount the MCP server host filesystem or implement the server's domain-specific evidence/business logic.

## Install

For first-time deployment and lifecycle operations:

**[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**

Default Docker image:

```text
egori4/cybercontroller-rdc-client:0.2.0
```

## Included commands

```bash
mcpctl health
mcpctl tools
mcpctl call <tool-name> '{"argument":"value"}'
```

Configuration:

- `MCP_URL` - MCP Streamable HTTP endpoint
- `MCP_BEARER_TOKEN_FILE` - recommended bearer-token file
- `MCP_BEARER_TOKEN` - optional environment fallback
- `MCP_CA_CERT_FILE` - optional CA certificate path

## Container boundary

Recommended deployment:

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

## Intentional feature reduction

Desktop Commander currently preemptively checks for Chrome for PDF generation. This image deliberately disables that PDF/Chrome path so the client does not download a browser at runtime. PDF generation is out of scope.

## Public-repo rule

Never commit:

- bearer tokens
- private keys
- environment/customer credentials
- Remote Desktop Commander device state

## Renamed in 0.2.0

Former repository: `egori4/rdc_client`. New image: `egori4/cybercontroller-rdc-client:0.2.0`. Existing container names, state/secrets volumes, environment variables, and internal paths intentionally remain unchanged. See [migration](docs/MIGRATION.md). The rename does not grant any new access.
