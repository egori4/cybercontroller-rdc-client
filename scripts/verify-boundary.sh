#!/bin/sh
set -eu

fail=0

check_absent() {
  path="$1"
  label="$2"
  if [ -e "$path" ]; then
    echo "FAIL: $label exists at $path"
    fail=1
  else
    echo "PASS: $label absent"
  fi
}

check_absent /var/run/docker.sock "Docker socket"
check_absent /host "host root mount"

if [ "$(id -u)" -eq 0 ]; then
  echo "FAIL: container runs as root"
  fail=1
else
  echo "PASS: non-root uid=$(id -u)"
fi

if touch /etc/rdc-client-should-fail 2>/dev/null; then
  echo "FAIL: root filesystem writable"
  rm -f /etc/rdc-client-should-fail || true
  fail=1
else
  echo "PASS: root filesystem read-only"
fi

exit "$fail"
