#!/bin/sh
set -eu

export HOME="${HOME:-/home/rdc}"

ca_file="${MCP_CA_CERT_FILE:-/run/rdc-client/ca.crt}"
if [ -z "${NODE_EXTRA_CA_CERTS:-}" ] && [ -f "$ca_file" ]; then
  export NODE_EXTRA_CA_CERTS="$ca_file"
fi

exec "$@"
