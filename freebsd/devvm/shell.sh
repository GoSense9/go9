#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
exec ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1"
