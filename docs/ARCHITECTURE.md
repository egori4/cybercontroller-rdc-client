# Architecture

## Responsibility

RDC Client is a thin remote-access client.

It owns:

- Desktop Commander Remote runtime
- MCP client transport
- local container hardening
- RDC device/session persistence

It does **not** own:

- CyberController evidence collection
- product-specific log mappings
- query safety policy
- filesystem access to the MCP server host
- remediation or configuration changes

Those controls remain server-side.

## Request path

```text
ChatGPT
  -> Desktop Commander cloud
  -> RDC Client container
  -> mcpctl
  -> MCP Streamable HTTP over TLS
  -> MCP server
```

The target MCP server is configured entirely through deployment settings.

## Trust boundary

The container is remotely controllable, so it is intentionally denied direct host access.

A compromise of the RDC session should expose only:

- the client container runtime
- the configured MCP endpoint
- the bearer credential available to that client
- responses that the MCP server authorizes

The MCP server remains responsible for authorization and server-side tool/query guardrails.
