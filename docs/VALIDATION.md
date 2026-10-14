# v0.3.0 validation — optional upstream RDC runtime updates

Date: 2026-10-14. Test machine: **m920q only**. No existing customer/CyberController RDC device was upgraded or restarted.

## Unit and build checks

| Test | Result |
| --- | --- |
| 7 mocked npm/startup updater tests (new install, cache reuse, offline, broken download, bad validation, prerelease rejection, disabled mode) | PASS |
| 3 MCP connection configuration tests | PASS |\n| Sanitized-shell mcpctl test with synthetic empty token file, no real credential | PASS on m920q |
| Docker image build (Node 22.23.3, bundled upstream RDC 0.2.52) | PASS |
| Bundled RDC remote help under non-root, read-only rootfs, capabilities dropped, no networking | PASS |

## Real restricted Docker validation on m920q

| Scenario | Result |
| --- | --- |
| Live npm latest resolution and install of upstream RDC **0.3.0** | PASS |
| Download and `remote --help` within **512 MiB RAM, 0.5 CPU, 96 PID**, UID/GID 10001, read-only rootfs, all capabilities dropped and no-new-privileges | PASS |
| Repeat with `--network none`, same test state volume, using cached 0.3.0 | PASS |
| `RDC_AUTO_UPDATE=false` uses image-bundled RDC 0.2.52 | PASS |
| Install disposable v0.2.0 client, upgrade via `update.sh` to v0.3.0 test image, retain stopped state, hostname, MCP_URL, pairing-state marker, token/CA volumes and restricted Docker boundary | PASS |
| Deliberately broken replacement image for a running disposable client; `update.sh` restores old container/image, running state and security boundary | PASS |
| Test resource teardown (disposable containers and volumes; no existing RDC devices changed) | PASS |

Observed cached runtime on volume after npm cache cleanup was approximately **255 MiB**. Plan sufficient storage for additional cached versions.

## Limitations and operator acceptance

- Unit tests mock npm and are not equivalent to a real remote cloud session.
- A successful CLI `remote --help` check is not proof that an upgraded, already paired device can reconnect to the Remote Desktop Commander cloud, nor that a real MCP token/CA can reach a production CyberController MCP endpoint.
- Live migration tests used **synthetic** tokens, a throwaway pairing marker, and disposable Docker containers. Live persistent identity after a real paired v0.2.0 upgrade remains an operator acceptance test.
- Startup selection validates download and CLI startup, **not** a long-running remote connection. A broken upstream remote process after startup is not automatically rolled back. Use `RDC_AUTO_UPDATE=false` via `update.sh` from an independent host-access path if needed.
- `update.sh` reconstructs the standard installation and does not promise to preserve undocumented custom mounts, user overrides or resource changes.

Before considering a target lab validated: make a secure backup of both named volumes, upgrade from independent host access, verify `verify-container.sh`, read version logs, confirm RDC dashboard online, and call `docker exec rdc-client mcpctl health` followed by a bounded real remote MCP call.
