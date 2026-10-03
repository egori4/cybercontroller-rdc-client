# RDC Client

A hardened Remote Desktop Commander container with a small generic MCP Streamable HTTP client.

RDC Client is an **optional bridge/consumer**, not an MCP server and not the only way to access one. An MCP server may instead be used directly by n8n, another MCP client, another agent platform, or custom automation.

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
egori4/rdc-client:0.1.0
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
