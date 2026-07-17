#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

mkdir -p "${GO9_VM_DIR}/seed"
[ -f "${SSH_KEY}" ] || ssh-keygen -t ed25519 -N '' -f "${SSH_KEY}"
PUB=$(cat "${SSH_KEY}.pub")

cat > "${GO9_VM_DIR}/seed/meta-data" <<META
instance-id: go9-freebsd-dev-root-v3
local-hostname: go9-freebsd-dev
META

cat > "${GO9_VM_DIR}/seed/user-data" <<USERDATA
#cloud-config
users:
  - default
ssh_authorized_keys:
  - ${PUB}
ssh_pwauth: false
disable_root: false
write_files:
  - path: /tmp/go9-root-authorized-key
    owner: root:wheel
    permissions: '0600'
    content: |
      ${PUB}
runcmd:
  - [ install, -d, -o, root, -g, wheel, -m, "0700", /root/.ssh ]
  - [ install, -o, root, -g, wheel, -m, "0600", /tmp/go9-root-authorized-key, /root/.ssh/authorized_keys ]
  - [ sh, -c, "printf '\nPermitRootLogin prohibit-password\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPerSourcePenalties no\n' >> /etc/ssh/sshd_config" ]
  - [ service, sshd, restart ]
  - [ sh, -c, "touch /var/run/go9-cloud-init-ready; echo GO9_CLOUD_INIT_READY > /dev/console" ]
USERDATA

if command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "${SEED_ISO}" "${GO9_VM_DIR}/seed/user-data" "${GO9_VM_DIR}/seed/meta-data"
elif command -v genisoimage >/dev/null 2>&1; then
  genisoimage -quiet -output "${SEED_ISO}" -volid cidata -joliet -rock "${GO9_VM_DIR}/seed/user-data" "${GO9_VM_DIR}/seed/meta-data"
elif command -v mkisofs >/dev/null 2>&1; then
  mkisofs -quiet -output "${SEED_ISO}" -volid cidata -joliet -rock "${GO9_VM_DIR}/seed/user-data" "${GO9_VM_DIR}/seed/meta-data"
else
  echo "missing cloud-localds, genisoimage, or mkisofs for NoCloud seed generation" >&2
  exit 1
fi

echo "Created NoCloud seed: ${SEED_ISO}"
