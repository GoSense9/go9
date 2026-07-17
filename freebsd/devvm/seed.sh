#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

mkdir -p "${GO9_VM_DIR}/seed"
[ -f "${SSH_KEY}" ] || ssh-keygen -t ed25519 -N '' -f "${SSH_KEY}"
PUB=$(cat "${SSH_KEY}.pub")
PUB_B64=$(printf '%s\n' "${PUB}" | base64 | tr -d '\n')

cat > "${GO9_VM_DIR}/seed/meta-data" <<META
instance-id: go9-freebsd-dev-root-v5
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
  - path: /root/go9-authorized-key.b64
    owner: root:wheel
    permissions: '0600'
    content: |
      ${PUB_B64}
  - path: /etc/ssh/sshd_config.go9-prefix
    owner: root:wheel
    permissions: '0600'
    content: |
      # GoSense9 localhost-only development VM policy.
      PermitRootLogin prohibit-password
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PubkeyAuthentication yes
      PerSourcePenalties no
runcmd:
  - [ sh, -c, "set -eu; install -d -o root -g wheel -m 0700 /root/.ssh; /usr/bin/base64 -d /root/go9-authorized-key.b64 > /root/.ssh/authorized_keys; chown root:wheel /root/.ssh/authorized_keys; chmod 0600 /root/.ssh/authorized_keys; /usr/bin/openssl rand -base64 48 | /usr/sbin/pw usermod root -h 0; cat /etc/ssh/sshd_config.go9-prefix /etc/ssh/sshd_config > /etc/ssh/sshd_config.go9-new; install -o root -g wheel -m 0600 /etc/ssh/sshd_config.go9-new /etc/ssh/sshd_config; /usr/sbin/sshd -t; /usr/sbin/sshd -T -C user=root,host=localhost,addr=10.0.2.2 | grep -Eq '^permitrootlogin (prohibit-password|without-password)$'; /usr/sbin/sshd -T -C user=root,host=localhost,addr=10.0.2.2 | grep -q '^pubkeyauthentication yes$'; service sshd restart; touch /var/run/go9-cloud-init-ready; echo GO9_CLOUD_INIT_READY > /dev/console" ]
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
