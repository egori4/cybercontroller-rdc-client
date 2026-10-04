#!/usr/bin/env bash
set -euo pipefail

name="${1:-rdc-client}"

docker container inspect "$name" >/dev/null

fail=0

check_json() {
  label="$1"
  expression="$2"
  expected="$3"
  actual="$(docker inspect "$name" | jq -r "$expression")"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label = $actual"
  else
    echo "FAIL: $label = $actual (expected $expected)"
    fail=1
  fi
}

check_json "runtime UID/GID" '.[0].Config.User' '10001:10001'
check_json "all capabilities dropped" '.[0].HostConfig.CapDrop | index("ALL") != null' 'true'
check_json "no-new-privileges" '.[0].HostConfig.SecurityOpt | any(startswith("no-new-privileges"))' 'true'
check_json "only named-volume mounts" '.[0].Mounts | all(.Type == "volume")' 'true'
check_json "secret volume read-only" '.[0].Mounts | any(.Destination == "/run/rdc-client" and .RW == false)' 'true'
check_json "memory limit" '.[0].HostConfig.Memory' '536870912'
check_json "CPU limit" '.[0].HostConfig.NanoCpus' '500000000'
check_json "PID limit" '.[0].HostConfig.PidsLimit' '96'

check_json "privileged" '.[0].HostConfig.Privileged' 'false'
check_json "read-only rootfs" '.[0].HostConfig.ReadonlyRootfs' 'true'
check_json "bridge networking" '.[0].HostConfig.NetworkMode | (. == "default" or . == "bridge")' 'true'
check_json "PID mode" '.[0].HostConfig.PidMode // ""' ''
check_json "IPC mode" '.[0].HostConfig.IpcMode // ""' 'private'
check_json "UTS mode" '.[0].HostConfig.UTSMode // ""' ''
check_json "restart policy" '.[0].HostConfig.RestartPolicy.Name' 'no'

ports="$(docker inspect "$name" | jq -c '.[0].HostConfig.PortBindings')"
if [[ "$ports" == "null" || "$ports" == "{}" ]]; then
  echo "PASS: no published ports"
else
  echo "FAIL: published ports: $ports"
  fail=1
fi

caps="$(docker inspect "$name" | jq -c '.[0].HostConfig.CapAdd')"
if [[ "$caps" == "null" || "$caps" == "[]" ]]; then
  echo "PASS: no added capabilities"
else
  echo "FAIL: added capabilities: $caps"
  fail=1
fi

if docker inspect "$name" | jq -e '.[0].Mounts[]? | select(.Source=="/var/run/docker.sock" or .Destination=="/var/run/docker.sock")' >/dev/null; then
  echo "FAIL: Docker socket mounted"
  fail=1
else
  echo "PASS: no Docker socket mount"
fi

if docker inspect "$name" | jq -e '.[0].Mounts[]? | select(.Source=="/" or .Destination=="/host")' >/dev/null; then
  echo "FAIL: host root mounted"
  fail=1
else
  echo "PASS: no host root mount"
fi

echo "--- configured limits ---"
docker inspect "$name" | jq '.[0].HostConfig | {
  Memory,
  MemorySwap,
  NanoCpus,
  PidsLimit,
  Ulimits,
  LogConfig
}'

exit "$fail"
