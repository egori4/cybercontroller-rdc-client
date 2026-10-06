#!/bin/sh
set -eu

# Desktop Commander launches remote commands with a deliberately sanitized
# environment. Restore only the non-secret MCP connection settings inherited
# by the container's PID 1 so mcpctl also works from RDC-started shells.
restore_from_pid1() {
  key="$1"
  eval "current=\${$key:-}"
  [ -n "$current" ] && return 0
  [ -r /proc/1/environ ] || return 0

  value="$(tr '\000' '\n' < /proc/1/environ | sed -n "s/^$key=//p" | head -n 1)"
  [ -n "$value" ] || return 0
  export "$key=$value"
}

restore_from_pid1 MCP_URL
restore_from_pid1 MCP_BEARER_TOKEN_FILE
restore_from_pid1 MCP_CA_CERT_FILE
restore_from_pid1 NODE_EXTRA_CA_CERTS

exec node /opt/rdc-client/src/mcpctl.mjs "$@"
