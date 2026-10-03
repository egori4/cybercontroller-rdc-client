#!/usr/bin/env bash
set -euo pipefail

IMAGE="${RDC_CLIENT_IMAGE:-rdc-client:0.1.0}"
CONTAINER_NAME="${CONTAINER_NAME:-rdc-client}"
STATE_VOLUME="${STATE_VOLUME:-rdc-client-state}"
SECRETS_VOLUME="${SECRETS_VOLUME:-rdc-client-secrets}"
RDC_DEVICE_NAME="${RDC_DEVICE_NAME:-}"
MCP_URL="${MCP_URL:-}"
START_NOW="${START_NOW:-}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || die "docker is required"
docker info >/dev/null 2>&1 || die "cannot access Docker"

if [[ -z "$RDC_DEVICE_NAME" ]]; then
  default_name="rdc-$(hostname -s 2>/dev/null || hostname)"
  if [[ -t 0 ]]; then
    read -r -p "RDC device name [$default_name]: " RDC_DEVICE_NAME
  fi
  RDC_DEVICE_NAME="${RDC_DEVICE_NAME:-$default_name}"
fi

if [[ -z "$MCP_URL" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "MCP URL (for example https://server:8443/mcp): " MCP_URL
  fi
  [[ -n "$MCP_URL" ]] || die "MCP_URL is required"
fi

[[ "$MCP_URL" =~ ^https?:// ]] || die "MCP_URL must begin with http:// or https://"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image $IMAGE is not local; pulling..."
  docker pull "$IMAGE"
fi

docker volume create "$STATE_VOLUME" >/dev/null
docker volume create "$SECRETS_VOLUME" >/dev/null

docker run --rm --user 0:0 \
  --mount "type=volume,src=$STATE_VOLUME,dst=/state" \
  --entrypoint sh "$IMAGE" \
  -c 'chown 10001:10001 /state && chmod 700 /state'

token_present=0
if docker run --rm \
  --mount "type=volume,src=$SECRETS_VOLUME,dst=/secrets,readonly" \
  --entrypoint sh "$IMAGE" -c 'test -s /secrets/token' >/dev/null 2>&1; then
  token_present=1
fi

if [[ -n "${MCP_BEARER_TOKEN:-}" ]]; then
  printf '%s' "$MCP_BEARER_TOKEN" | docker run --rm -i --user 0:0 \
    --mount "type=volume,src=$SECRETS_VOLUME,dst=/secrets" \
    --entrypoint sh "$IMAGE" \
    -c 'umask 077; cat > /secrets/token; chown 10001:10001 /secrets/token'
  token_present=1
elif [[ "$token_present" -eq 0 && -t 0 ]]; then
  read -r -s -p "MCP bearer token: " token
  echo
  [[ -n "$token" ]] || die "bearer token cannot be empty"
  printf '%s' "$token" | docker run --rm -i --user 0:0 \
    --mount "type=volume,src=$SECRETS_VOLUME,dst=/secrets" \
    --entrypoint sh "$IMAGE" \
    -c 'umask 077; cat > /secrets/token; chown 10001:10001 /secrets/token'
  unset token
  token_present=1
fi

[[ "$token_present" -eq 1 ]] || die "no bearer token is available; set MCP_BEARER_TOKEN or pre-populate $SECRETS_VOLUME"

if [[ -n "${MCP_CA_SOURCE:-}" ]]; then
  [[ -f "$MCP_CA_SOURCE" ]] || die "MCP_CA_SOURCE does not exist: $MCP_CA_SOURCE"
  cat "$MCP_CA_SOURCE" | docker run --rm -i --user 0:0 \
    --mount "type=volume,src=$SECRETS_VOLUME,dst=/secrets" \
    --entrypoint sh "$IMAGE" \
    -c 'cat > /secrets/ca.crt; chown 10001:10001 /secrets/ca.crt; chmod 0444 /secrets/ca.crt'
fi

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  if [[ -t 0 ]]; then
    read -r -p "Container $CONTAINER_NAME exists. Recreate it? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || die "cancelled"
  else
    die "container $CONTAINER_NAME already exists"
  fi
  docker rm -f "$CONTAINER_NAME" >/dev/null
fi

docker create \
  --name "$CONTAINER_NAME" \
  --hostname "$RDC_DEVICE_NAME" \
  --user 10001:10001 \
  --restart=no \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --pids-limit 96 \
  --memory 512m \
  --memory-swap 512m \
  --cpus 0.5 \
  --ulimit nofile=1024:1024 \
  --log-driver local \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m,uid=10001,gid=10001,mode=1777 \
  --tmpfs /home/rdc/.claude-server-commander:rw,noexec,nosuid,nodev,size=32m,uid=10001,gid=10001,mode=700 \
  --tmpfs /home/rdc/.npm:rw,noexec,nosuid,nodev,size=8m,uid=10001,gid=10001,mode=700 \
  --mount "type=volume,src=$STATE_VOLUME,dst=/home/rdc/.desktop-commander-device" \
  --mount "type=volume,src=$SECRETS_VOLUME,dst=/run/rdc-client,readonly" \
  --env "MCP_URL=$MCP_URL" \
  "$IMAGE" >/dev/null

echo "Created hardened container: $CONTAINER_NAME"
echo "RDC device name: $RDC_DEVICE_NAME"
echo "MCP endpoint: $MCP_URL"
echo
echo "Verify boundary:"
echo "  scripts/verify-container.sh $CONTAINER_NAME"
echo
echo "First pairing:"
echo "  docker start -ai $CONTAINER_NAME"
echo
echo "Access off:"
echo "  docker stop $CONTAINER_NAME"

if [[ -z "$START_NOW" && -t 0 ]]; then
  read -r -p "Start now for RDC pairing? [Y/n]: " START_NOW
  START_NOW="${START_NOW:-y}"
fi

if [[ "$START_NOW" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  exec docker start -ai "$CONTAINER_NAME"
fi
