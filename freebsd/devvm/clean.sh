#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
"${ROOT}/freebsd/devvm/down.sh"
rm -f "${OVERLAY_IMAGE}" "${SEED_ISO}" "${LOG_FILE}" "${GO9_VM_DIR}/go9-freebsd-amd64" "${GO9_VM_DIR}/dashboard.html" "${GO9_VM_DIR}/status.html"
rm -rf "${GO9_VM_DIR}/seed"
echo "Cleaned VM overlay and generated runtime files; base image is preserved."
