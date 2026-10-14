#!/usr/bin/env bash
# Safely replace the restricted client image, retaining paired state/secrets and a stopped rollback container.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
IMAGE=${1:-}
NAME=${CONTAINER_NAME:-rdc-client}
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $# -eq 1 && -n "$IMAGE" ]] || fail "Usage: RDC_AUTO_UPDATE=true ./update.sh <image:version-or-digest>"
command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 || fail "Docker access required"

old_project=$(docker inspect "$NAME" --format '{{index .Config.Labels "io.egori4.project"}}') || fail "Container not found: $NAME"
old_role=$(docker inspect "$NAME" --format '{{index .Config.Labels "io.egori4.security-profile"}}')
[[ "$old_project" == cybercontroller-rdc-client && "$old_role" == restricted ]] ||
    fail "Refusing to replace an unrelated/unrecognized container: $NAME"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then docker pull "$IMAGE"; fi
new_project=$(docker image inspect "$IMAGE" --format '{{index .Config.Labels "io.egori4.project"}}')
new_role=$(docker image inspect "$IMAGE" --format '{{index .Config.Labels "io.egori4.security-profile"}}')
[[ "$new_project" == cybercontroller-rdc-client && "$new_role" == restricted ]] ||
    fail "Image is not a restricted CyberController RDC client: $IMAGE"

get_env() {
    docker inspect "$NAME" --format '{{range .Config.Env}}{{println .}}{{end}}' |
        sed -n "s/^$1=//p" | head -n 1
}
DEVICE=$(docker inspect "$NAME" --format '{{.Config.Hostname}}')
MCP_URL=$(get_env MCP_URL)
[[ -n "$MCP_URL" ]] || fail "MCP_URL is missing from the existing container"
STATE=$(docker inspect "$NAME" --format '{{range .Mounts}}{{if eq .Destination "/home/rdc/.desktop-commander-device"}}{{.Name}}{{end}}{{end}}')
SECRETS=$(docker inspect "$NAME" --format '{{range .Mounts}}{{if eq .Destination "/run/rdc-client"}}{{.Name}}{{end}}{{end}}')
[[ -n "$STATE" && -n "$SECRETS" ]] || fail "Existing state or secrets volume missing"
OLD_AUTO=$(get_env RDC_AUTO_UPDATE)
AUTO=${RDC_AUTO_UPDATE:-${OLD_AUTO:-false}}
[[ "$AUTO" == true || "$AUTO" == false ]] || fail "RDC_AUTO_UPDATE must be true or false"
RUNNING=$(docker inspect "$NAME" --format '{{.State.Running}}')
BACKUP="${NAME}-rollback-$(date -u +%Y%m%dT%H%M%SZ)"
if docker inspect "$BACKUP" >/dev/null 2>&1; then fail "Rollback name exists: $BACKUP"; fi

rollback() {
    local status=$?
    trap - ERR INT TERM
    echo "Update failed; restoring $NAME (backup: $BACKUP)" >&2
    if docker container inspect "$BACKUP" >/dev/null 2>&1; then
        if docker container inspect "$NAME" >/dev/null 2>&1; then
            project=$(docker inspect "$NAME" --format '{{index .Config.Labels "io.egori4.project"}}')
            [[ "$project" == cybercontroller-rdc-client ]] ||
                fail "A different container now owns $NAME; recover $BACKUP manually"
            docker rm -f "$NAME" >/dev/null || true
        fi
        docker rename "$BACKUP" "$NAME" || true
    fi
    if [[ "$RUNNING" == true ]] && docker container inspect "$NAME" >/dev/null 2>&1; then
        [[ "$(docker inspect "$NAME" --format '{{.State.Running}}')" == true ]] ||
            docker start "$NAME" >/dev/null || true
    fi
    exit "$status"
}
trap rollback ERR INT TERM
if [[ "$RUNNING" == true ]]; then docker stop "$NAME" >/dev/null; fi
docker rename "$NAME" "$BACKUP"

# Existing secrets/CA are reused, not copied into process args or written to disk.
RDC_CLIENT_IMAGE="$IMAGE" CONTAINER_NAME="$NAME" STATE_VOLUME="$STATE" \
    SECRETS_VOLUME="$SECRETS" RDC_DEVICE_NAME="$DEVICE" MCP_URL="$MCP_URL" \
    MCP_CA_SOURCE="" MCP_BEARER_TOKEN="" RDC_AUTO_UPDATE="$AUTO" START_NOW=n \
    "$ROOT/install.sh"

if [[ "$RUNNING" == true ]]; then
    docker start "$NAME" >/dev/null
    sleep 3
    [[ "$(docker inspect "$NAME" --format '{{.State.Running}}')" == true ]]
fi
trap - ERR INT TERM
printf 'Updated %s to %s; RDC_AUTO_UPDATE=%s\n' "$NAME" "$IMAGE" "$AUTO"
printf 'Stopped rollback container: %s\n' "$BACKUP"
echo "Verify: ./scripts/verify-container.sh $NAME; docker logs --tail 40 $NAME"
echo "Do not start the rollback container while the new instance shares the same state volume."
