#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
mkdir -p "${GO9_VM_DIR}"
[ -f "${CHECKSUM_FILE}" ] || curl -fL "${BASE_URL}/CHECKSUM.SHA256" -o "${CHECKSUM_FILE}"
[ -f "${BASE_IMAGE}" ] || curl -fL "${BASE_URL}/${IMAGE_BASENAME}" -o "${BASE_IMAGE}"
( cd "${GO9_VM_DIR}" && grep "(${IMAGE_BASENAME})" CHECKSUM.SHA256 | sha256sum -c - )
chmod 0444 "${BASE_IMAGE}"
echo "Verified immutable base image: ${BASE_IMAGE}"
