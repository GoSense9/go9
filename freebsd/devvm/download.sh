#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
mkdir -p "${GO9_VM_DIR}"

download_atomic() {
    url=$1
    destination=$2
    temporary="${destination}.part"
    rm -f "${temporary}"
    if ! curl -fL --retry 3 --retry-delay 2 "${url}" -o "${temporary}"; then
        rm -f "${temporary}"
        return 1
    fi
    mv "${temporary}" "${destination}"
}

if [ ! -f "${CHECKSUM_FILE}" ]; then
    download_atomic "${BASE_URL}/CHECKSUM.SHA256" "${CHECKSUM_FILE}"
fi

EXPECTED_HASH=$(awk -v target="(${ARCHIVE_BASENAME})" 'index($0, target) { print $4; exit }' "${CHECKSUM_FILE}")
if [ -z "${EXPECTED_HASH}" ]; then
    echo "checksum entry not found for ${ARCHIVE_BASENAME}" >&2
    exit 1
fi

if [ -f "${BASE_ARCHIVE}" ]; then
    ACTUAL_HASH=$(sha256sum "${BASE_ARCHIVE}" | awk '{print $1}')
    if [ "${ACTUAL_HASH}" != "${EXPECTED_HASH}" ]; then
        echo "removing invalid cached archive: ${BASE_ARCHIVE}" >&2
        chmod u+w "${BASE_ARCHIVE}" 2>/dev/null || true
        rm -f "${BASE_ARCHIVE}"
    fi
fi

if [ ! -f "${BASE_ARCHIVE}" ]; then
    download_atomic "${BASE_URL}/${ARCHIVE_BASENAME}" "${BASE_ARCHIVE}"
fi

ACTUAL_HASH=$(sha256sum "${BASE_ARCHIVE}" | awk '{print $1}')
if [ "${ACTUAL_HASH}" != "${EXPECTED_HASH}" ]; then
    echo "SHA-256 verification failed for ${ARCHIVE_BASENAME}" >&2
    exit 1
fi

if [ -f "${BASE_IMAGE}" ] && ! qemu-img info "${BASE_IMAGE}" >/dev/null 2>&1; then
    echo "removing invalid extracted image: ${BASE_IMAGE}" >&2
    chmod u+w "${BASE_IMAGE}" 2>/dev/null || true
    rm -f "${BASE_IMAGE}"
fi

if [ ! -f "${BASE_IMAGE}" ]; then
    temporary_image="${BASE_IMAGE}.part"
    rm -f "${temporary_image}"
    echo "Extracting ${ARCHIVE_BASENAME}..."
    if ! xz -dc "${BASE_ARCHIVE}" > "${temporary_image}"; then
        rm -f "${temporary_image}"
        exit 1
    fi
    qemu-img info "${temporary_image}" >/dev/null
    mv "${temporary_image}" "${BASE_IMAGE}"
fi

chmod 0444 "${BASE_ARCHIVE}" "${BASE_IMAGE}"
echo "Verified immutable base image: ${BASE_IMAGE}"
