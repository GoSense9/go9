#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
if [ -f "${PID_FILE}" ] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
  kill "$(cat "${PID_FILE}")"
  i=0; while [ "$i" -lt 30 ] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; do i=$((i+1)); sleep 1; done
  kill -9 "$(cat "${PID_FILE}")" 2>/dev/null || true
fi
rm -f "${PID_FILE}"
echo "VM stopped."
