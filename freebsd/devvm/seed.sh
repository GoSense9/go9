#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
mkdir -p "${GO9_VM_DIR}/seed"
[ -f "${SSH_KEY}" ] || ssh-keygen -t ed25519 -N '' -f "${SSH_KEY}"
PUB=$(cat "${SSH_KEY}.pub")
cat > "${GO9_VM_DIR}/seed/meta-data" <<META
instance-id: go9-freebsd-dev
local-hostname: go9-freebsd-dev
META
cat > "${GO9_VM_DIR}/seed/user-data" <<USERDATA
#cloud-config
users:
  - name: ${VM_USER}
    groups: wheel
    shell: /bin/sh
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${PUB}
ssh_pwauth: false
disable_root: true
chpasswd:
  expire: false
USERDATA
if command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "${SEED_ISO}" "${GO9_VM_DIR}/seed/user-data" "${GO9_VM_DIR}/seed/meta-data"
elif command -v genisoimage >/dev/null 2>&1; then
  genisoimage -quiet -output "${SEED_ISO}" -volid cidata -joliet -rock "${GO9_VM_DIR}/seed/user-data" "${GO9_VM_DIR}/seed/meta-data"
elif command -v mkisofs >/dev/null 2>&1; then
  mkisofs -quiet -output "${SEED_ISO}" -volid cidata -joliet -rock "${GO9_VM_DIR}/seed/user-data" "${GO9_VM_DIR}/seed/meta-data"
else
  echo "missing cloud-localds, genisoimage, or mkisofs for NoCloud seed generation" >&2; exit 1
fi
echo "Created NoCloud seed: ${SEED_ISO}"
