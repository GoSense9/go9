#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
[ -f "${LOG_FILE}" ] && tail -n 200 -f "${LOG_FILE}" || { echo "no QEMU log at ${LOG_FILE}" >&2; exit 1; }
