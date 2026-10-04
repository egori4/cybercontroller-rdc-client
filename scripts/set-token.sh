#!/usr/bin/env bash
set -euo pipefail

IMAGE="${RDC_CLIENT_IMAGE:-egori4/cybercontroller-rdc-client:0.2.0}"
SECRETS_VOLUME="${SECRETS_VOLUME:-rdc-client-secrets}"
CONTAINER_NAME="${CONTAINER_NAME:-rdc-client}"

if [[ -n "${MCP_BEARER_TOKEN:-}" ]]; then
  token="$MCP_BEARER_TOKEN"
else
  read -r -s -p "New MCP bearer token: " token
  echo
fi

[[ -n "$token" ]] || { echo "ERROR: token cannot be empty" >&2; exit 1; }

printf '%s' "$token" | docker run --rm -i --user 0:0   --mount "type=volume,src=$SECRETS_VOLUME,dst=/secrets"   --entrypoint sh "$IMAGE"   -c 'umask 077; cat > /secrets/token; chown 10001:10001 /secrets/token'
unset token

echo "Updated token in Docker volume $SECRETS_VOLUME."
echo "Restart $CONTAINER_NAME if it is running:"
echo "  docker restart $CONTAINER_NAME"
