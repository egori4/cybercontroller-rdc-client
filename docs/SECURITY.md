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

Persistent writable storage is limited to the Desktop Commander device state directory (`rdc-client-state`). With optional runtime updates, `runtime/versions` beneath **that same state volume** holds downloaded executable JavaScript and npm dependencies; the adjacent npm download cache is removed after each startup. **No host mount, Docker socket, root privileges, extra volume or additional writable system path is introduced.** Treat the whole volume as sensitive and back it up before upgrading. Versioned installs may consume hundreds of MiB each; monitor disk capacity and manage old cached versions.

Other Desktop Commander runtime/cache locations use bounded tmpfs mounts. The separate persistent runtime cache is intentionally not subject to the 8 MiB npm tmpfs limit.

## Automatic upstream updates

`RDC_AUTO_UPDATE=true` opts in to running newly published, otherwise unreviewed upstream npm packages. Installs run as restricted UID 10001, but remotely controlled code can still read the RDC pairing and available MCP bearer token, so this is a supply-chain and credential-exposure decision. npm integrity checking and CLI `remote --help` validation do not guarantee security or real cloud connectivity.

The default is **false**. Only stable `latest` versions matching numeric semver are selected. Network failures and failed validation use the last selected cached version (or image-bundled 0.2.52), not an arbitrary partially installed package. The updater runs only at startup and **does not test/revert after a runtime is successfully launched**. Package compatibility may require an image rebuild for newer Node.js/system dependencies; do not depend on permanent compatibility.

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
