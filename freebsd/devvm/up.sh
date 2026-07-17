#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

"${ROOT}/freebsd/devvm/prerequisites.sh"
"${ROOT}/freebsd/devvm/download.sh"
"${ROOT}/freebsd/devvm/seed.sh"

if [ -f "${PID_FILE}" ]; then
  PID=$(cat "${PID_FILE}" 2>/dev/null || true)
  if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
    if ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" 'true' >/dev/null 2>&1; then
      echo "VM already running and reachable"
      exit 0
    fi
    echo "VM is running but does not accept the current project root key." >&2
    echo "Recreate the ephemeral VM with: make freebsd-vm-clean && make freebsd-dev" >&2
    exit 1
  fi
  rm -f "${PID_FILE}"
fi

BASE_IMAGE_ABS=$(readlink -f "${BASE_IMAGE}")
OVERLAY_IMAGE_ABS="${ROOT}/${OVERLAY_IMAGE}"
SEED_ISO_ABS="${ROOT}/${SEED_ISO}"
LOG_FILE_ABS="${ROOT}/${LOG_FILE}"
PID_FILE_ABS="${ROOT}/${PID_FILE}"
SSH_DEBUG_FILE="${GO9_VM_DIR}/ssh-debug.log"

if [ -f "${OVERLAY_IMAGE}" ] && ! qemu-img info "${OVERLAY_IMAGE}" >/dev/null 2>&1; then
  echo "Removing invalid FreeBSD overlay: ${OVERLAY_IMAGE}"
  rm -f "${OVERLAY_IMAGE}"
fi

if [ ! -f "${OVERLAY_IMAGE}" ]; then
  qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMAGE_ABS}" "${OVERLAY_IMAGE_ABS}"
fi

ACCEL="tcg"
[ -e /dev/kvm ] && ACCEL="kvm:tcg"

rm -f "${LOG_FILE}" "${SSH_DEBUG_FILE}"

qemu-system-x86_64 \
  -daemonize \
  -pidfile "${PID_FILE_ABS}" \
  -name go9-freebsd-dev \
  -m "${GO9_VM_MEMORY}" \
  -smp "${GO9_VM_CPUS}" \
  -machine accel="${ACCEL}" \
  -drive "file=${OVERLAY_IMAGE_ABS},if=virtio,format=qcow2" \
  -drive "file=${SEED_ISO_ABS},if=virtio,media=cdrom,readonly=on" \
  -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${GO9_VM_SSH_PORT}-:22,hostfwd=tcp:127.0.0.1:${GO9_VM_WEB_PORT}-:8080" \
  -device virtio-net-pci,netdev=net0 \
  -serial "file:${LOG_FILE_ABS}" \
  -display none

print_diagnostics() {
  if [ -f "${PID_FILE}" ]; then
    PID=$(cat "${PID_FILE}" 2>/dev/null || true)
    if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
      echo "QEMU is still running with PID ${PID}." >&2
    else
      echo "QEMU is not running; the VM exited during boot." >&2
    fi
  else
    echo "QEMU PID file is missing." >&2
  fi

  ssh -vvv ${SSH_OPTS} "${VM_USER}@127.0.0.1" 'true' >"${SSH_DEBUG_FILE}" 2>&1 || true

  if [ -f "${LOG_FILE}" ]; then
    echo "--- Last 160 lines of QEMU serial log ---" >&2
    tail -n 160 "${LOG_FILE}" >&2 || true
  fi

  if [ -f "${SSH_DEBUG_FILE}" ]; then
    echo "--- Last 100 lines of SSH diagnostics ---" >&2
    tail -n 100 "${SSH_DEBUG_FILE}" >&2 || true
  fi

  echo "Full logs: ${LOG_FILE} and ${SSH_DEBUG_FILE}" >&2
}

printf 'Waiting for FreeBSD cloud-init'
READY=0
i=0
while [ "${i}" -lt 180 ]; do
  if [ -f "${LOG_FILE}" ] && grep -q 'GO9_CLOUD_INIT_READY' "${LOG_FILE}"; then
    READY=1
    break
  fi

  if [ -f "${PID_FILE}" ]; then
    PID=$(cat "${PID_FILE}" 2>/dev/null || true)
    if [ -z "${PID}" ] || ! kill -0 "${PID}" 2>/dev/null; then
      break
    fi
  fi

  i=$((i+1))
  printf .
  sleep 2
done
echo

if [ "${READY}" -ne 1 ]; then
  echo "timed out waiting for FreeBSD cloud-init readiness marker" >&2
  print_diagnostics
  exit 1
fi

printf 'Waiting for root SSH'
i=0
while [ "${i}" -lt 12 ]; do
  if ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" 'true' >/dev/null 2>&1; then
    echo
    echo "VM is reachable"
    exit 0
  fi
  i=$((i+1))
  printf .
  sleep 5
done
echo

echo "cloud-init completed, but root SSH did not become reachable" >&2
print_diagnostics
exit 1
