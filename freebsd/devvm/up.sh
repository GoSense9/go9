#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
"${ROOT}/freebsd/devvm/prerequisites.sh"
"${ROOT}/freebsd/devvm/download.sh"
"${ROOT}/freebsd/devvm/seed.sh"
if [ -f "${PID_FILE}" ] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then echo "VM already running"; exit 0; fi
[ -f "${OVERLAY_IMAGE}" ] || qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMAGE}" "${OVERLAY_IMAGE}"
ACCEL="tcg"
[ -e /dev/kvm ] && ACCEL="kvm:tcg"
qemu-system-x86_64 -daemonize -pidfile "${PID_FILE}" -name go9-freebsd-dev -m "${GO9_VM_MEMORY}" -smp "${GO9_VM_CPUS}" -machine accel="${ACCEL}" -drive "file=${OVERLAY_IMAGE},if=virtio,format=qcow2" -drive "file=${SEED_ISO},if=virtio,media=cdrom,readonly=on" -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${GO9_VM_SSH_PORT}-:22,hostfwd=tcp:127.0.0.1:${GO9_VM_WEB_PORT}-:8080" -device virtio-net-pci,netdev=net0 -serial "file:${LOG_FILE}" -display none
printf 'Waiting for SSH'
i=0; while [ "$i" -lt 120 ]; do
  if ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" 'true' >/dev/null 2>&1; then echo; echo "VM is reachable"; exit 0; fi
  i=$((i+1)); printf .; sleep 2
done
echo; echo "timed out waiting for SSH; inspect ${LOG_FILE}" >&2; exit 1
