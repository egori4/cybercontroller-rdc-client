# Changelog

## 0.3.0

- Add optional startup-only Desktop Commander runtime updates (`RDC_AUTO_UPDATE=true`) from npm stable, with persistent version cache and packaged 0.2.52 fallback.
- Preserve non-root UID 10001, read-only root filesystem, capability drop, resource limits, Docker bridge network, and existing MCP token/CA volume boundaries.
- Add `update.sh` for rollback-capable image upgrades that preserve pairing, MCP endpoint and credentials, with a way to enable/disable the updater.
- Add runtime tests, README and detailed operational/security documentation.


## 0.2.0

- Rename `egori4/rdc_client` to `egori4/cybercontroller-rdc-client`, preserving Git history.
- Publish under `egori4/cybercontroller-rdc-client`; retain runtime object/path compatibility.
- Explicitly separate the restricted CyberController client from generic `rdc-host-admin`.
- Pin Desktop Commander to 0.2.52 rather than resolving `latest` during release.
- Add migration guidance and current, commit-pinned CI actions with release validation.
- No additional host permissions; no privileged/full mode.
