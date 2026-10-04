# Changelog

## 0.2.0

- Rename `egori4/rdc_client` to `egori4/cybercontroller-rdc-client`, preserving Git history.
- Publish under `egori4/cybercontroller-rdc-client`; retain runtime object/path compatibility.
- Explicitly separate the restricted CyberController client from generic `rdc-host-admin`.
- Pin Desktop Commander to 0.2.52 rather than resolving `latest` during release.
- Add migration guidance and current, commit-pinned CI actions with release validation.
- No additional host permissions; no privileged/full mode.
