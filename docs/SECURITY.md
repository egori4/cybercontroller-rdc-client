# Security

## Recommended runtime controls

The deployment container should use:

```text
--read-only
--cap-drop ALL
--security-opt no-new-privileges
--pids-limit 96
--memory 512m
--cpus 0.5
--ulimit nofile=1024:1024
```

No host port is published.

Do not mount:

- `/var/run/docker.sock`
- host `/`
- host log directories
- application configuration directories

Do not use:

- `--privileged`
- `--pid=host`
- `--network=host`
- `--ipc=host`
- `--uts=host`

## Writable storage

Persistent writable storage should be limited to the Desktop Commander device state directory.

Other Desktop Commander runtime/cache locations should use bounded tmpfs mounts.

## MCP credential

Prefer a read-only token file rather than an environment variable.

The token should grant only the permissions intended by the MCP server.

## TLS

Use normal certificate validation.

For private/self-signed lab PKI, mount only the CA/server certificate needed for trust and configure `MCP_CA_CERT_FILE`.

Do not disable TLS verification in the standard deployment.

## Runtime browser downloads

Desktop Commander currently prefetches Chrome for PDF generation. The image provides a nonfunctional Chromium placeholder so that startup does not download a browser into runtime storage. PDF generation is intentionally unsupported.

## Residual risk

The container uses normal Docker bridge networking. It is not an outbound network sandbox.

Security therefore depends on:

- no direct host mounts/control surfaces
- non-root runtime
- empty Linux capability set
- server-side MCP authorization/guardrails
- appropriate network policy outside this project where required
