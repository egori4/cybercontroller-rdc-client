# Deployment

## Prerequisites

Target host:

- Docker installed and running
- outbound Internet access required by Desktop Commander Remote
- network reachability to the configured MCP endpoint
- no host Node.js/npm requirement

Build the image outside the target host.

## Required deployment values

### RDC device name

Unique name shown by Desktop Commander.

Example:

```text
cc-lab-mcp-client
```

### MCP URL

Example:

```text
https://server.example.net:8443/mcp
```

### Bearer token

Store in a Docker named volume as:

```text
/run/rdc-client/token
```

### Optional CA certificate

For private/self-signed PKI, store the trusted certificate as:

```text
/run/rdc-client/ca.crt
```

## Recommended Docker objects

Named volumes:

```text
rdc-client-state
rdc-client-secrets
```

The state volume persists only Desktop Commander device authorization.

The secrets volume contains only MCP client credential/trust material.

## Runtime settings

Recommended:

```text
restart=no
read-only root filesystem
UID/GID 10001
cap-drop ALL
no-new-privileges
0.5 CPU
512 MiB memory
96 PIDs
1024 open files
64 MiB /tmp
32 MiB Desktop Commander runtime tmpfs
no published ports
normal bridge networking
```

## Lifecycle

Running container:

```bash
docker start rdc-client
```

Access off:

```bash
docker stop rdc-client
```

First pairing:

```bash
docker start -ai rdc-client
```

## MCP verification

Inside the running container:

```bash
docker exec rdc-client mcpctl health
docker exec rdc-client mcpctl tools
```

The server's own documentation defines available tools and their arguments.
