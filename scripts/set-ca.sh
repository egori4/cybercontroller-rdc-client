#!/usr/bin/env bash
set -euo pipefail

IMAGE="${RDC_CLIENT_IMAGE:-egori4/rdc-client:0.1.0}"
SECRETS_VOLUME="${SECRETS_VOLUME:-rdc-client-secrets}"
CONTAINER_NAME="${CONTAINER_NAME:-rdc-client}"
SOURCE="${1:-}"

[[ -n "$SOURCE" ]] || { echo "Usage: $0 /path/to/ca.crt" >&2; exit 2; }
[[ -f "$SOURCE" ]] || { echo "ERROR: file not found: $SOURCE" >&2; exit 1; }

cat "$SOURCE" | docker run --rm -i --user 0:0   --mount "type=volume,src=$SECRETS_VOLUME,dst=/secrets"   --entrypoint sh "$IMAGE"   -c 'cat > /secrets/ca.crt; chown 10001:10001 /secrets/ca.crt; chmod 0444 /secrets/ca.crt'

echo "Updated CA certificate in Docker volume $SECRETS_VOLUME."
echo "Recreate $CONTAINER_NAME if it was originally created without NODE_EXTRA_CA_CERTS."
echo "Otherwise restart it:"
echo "  docker restart $CONTAINER_NAME"
