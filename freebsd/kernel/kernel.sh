#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

KERNEL_CONF=GO9_VM
KERNEL_INSTALL_NAME=kernel.go9vm
FREEBSD_SRC_BRANCH=releng/15.1
BUILD_DISK_IDENT=GO9KERNELBUILD
BUILD_LABEL=go9build
BUILD_MOUNT=/mnt/go9-kernel
FREEBSD_SRC_DIR=${BUILD_MOUNT}/src
FREEBSD_OBJ_DIR=${BUILD_MOUNT}/obj
MIN_FREE_KB=8000000

usage() {
  cat <<'EOF'
usage: sh freebsd/kernel/kernel.sh <prepare|build|install|test|boot-test|status|clean-build-disk>

  prepare          initialize the dedicated build disk, install Git, obtain
                   releng/15.1 source, and stage GO9_VM
  build            build the kernel toolchain, GO9_VM kernel, and selected modules
  install          install under /boot/kernel.go9vm without replacing GENERIC
  test             validate the currently running kernel and GoSense9 service
  boot-test         schedule one GO9_VM boot with nextboot, reboot, wait, and test
  status           show source, build disk, installed kernel, nextboot, and runtime state
  clean-build-disk remove the persistent host build disk; VM must be stopped
EOF
}

ssh_guest() {
  ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" "$@"
}

require_vm() {
  if ! ssh_guest 'true' >/dev/null 2>&1; then
    echo "FreeBSD VM is not reachable. Run: make freebsd-vm-up" >&2
    exit 1
  fi
}

initialize_build_disk() {
  require_vm

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    BUILD_DEVICE=\$(geom disk list | awk '
      /^Geom name:/ { disk = \$3 }
      /^[[:space:]]*ident: ${BUILD_DISK_IDENT}[[:space:]]*\$/ { print \"/dev/\" disk; exit }
    ')

    if [ -z \"\${BUILD_DEVICE}\" ] || [ ! -e \"\${BUILD_DEVICE}\" ]; then
      echo \"Dedicated kernel build disk with ident ${BUILD_DISK_IDENT} was not found.\" >&2
      echo \"Stop and restart the VM after pulling M1: make freebsd-vm-down && make freebsd-vm-up\" >&2
      exit 1
    fi

    if [ ! -e /dev/gpt/${BUILD_LABEL} ]; then
      if \"\${DOAS}\" -n gpart show \"\${BUILD_DEVICE}\" >/dev/null 2>&1; then
        echo \"Refusing to format \${BUILD_DEVICE}: it already has an unknown partition table.\" >&2
        \"\${DOAS}\" -n gpart show \"\${BUILD_DEVICE}\" >&2 || true
        exit 1
      fi

      echo \"Initializing dedicated kernel build disk: \${BUILD_DEVICE}\"
      \"\${DOAS}\" -n gpart create -s gpt \"\${BUILD_DEVICE}\"
      \"\${DOAS}\" -n gpart add -a 1m -t freebsd-ufs -l ${BUILD_LABEL} \"\${BUILD_DEVICE}\"
      \"\${DOAS}\" -n newfs -U /dev/gpt/${BUILD_LABEL}
    fi

    \"\${DOAS}\" -n mkdir -p ${BUILD_MOUNT}
    if ! mount -p | awk '\$1 == \"/dev/gpt/${BUILD_LABEL}\" && \$2 == \"${BUILD_MOUNT}\" { found = 1 } END { exit !found }'; then
      \"\${DOAS}\" -n mount -o noatime /dev/gpt/${BUILD_LABEL} ${BUILD_MOUNT}
    fi

    \"\${DOAS}\" -n mkdir -p ${FREEBSD_SRC_DIR} ${FREEBSD_OBJ_DIR}
    AVAILABLE_KB=\$(df -k ${BUILD_MOUNT} | awk 'NR == 2 { print \$4 }')
    if [ \"\${AVAILABLE_KB}\" -lt ${MIN_FREE_KB} ]; then
      echo \"GO9_VM build requires at least ${MIN_FREE_KB} KiB free on ${BUILD_MOUNT}; available: \${AVAILABLE_KB} KiB\" >&2
      exit 1
    fi
  "
}

mount_existing_build_disk() {
  require_vm
  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    test -e /dev/gpt/${BUILD_LABEL}
    \"\${DOAS}\" -n mkdir -p ${BUILD_MOUNT}
    if ! mount -p | awk '\$1 == \"/dev/gpt/${BUILD_LABEL}\" && \$2 == \"${BUILD_MOUNT}\" { found = 1 } END { exit !found }'; then
      \"\${DOAS}\" -n mount -o noatime /dev/gpt/${BUILD_LABEL} ${BUILD_MOUNT}
    fi
  "
}

stage_config() {
  scp ${SCP_OPTS} "${ROOT}/freebsd/kernel/${KERNEL_CONF}" \
    "${VM_USER}@127.0.0.1:/tmp/${KERNEL_CONF}"
  ssh_guest "set -eu
    test -d ${FREEBSD_SRC_DIR}/sys/amd64/conf
    /usr/local/bin/doas -n install -o root -g wheel -m 0644 \
      /tmp/${KERNEL_CONF} ${FREEBSD_SRC_DIR}/sys/amd64/conf/${KERNEL_CONF}
  "
}

prepare_source() {
  initialize_build_disk

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas

    if ! command -v git >/dev/null 2>&1; then
      \"\${DOAS}\" -n pkg install -y git
    fi

    if [ ! -d ${FREEBSD_SRC_DIR}/.git ]; then
      if [ -n \"\$(find ${FREEBSD_SRC_DIR} -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)\" ]; then
        echo \"Refusing to replace unmanaged source path: ${FREEBSD_SRC_DIR}\" >&2
        exit 1
      fi
      \"\${DOAS}\" -n git clone --depth 1 --single-branch --branch ${FREEBSD_SRC_BRANCH} \
        https://git.FreeBSD.org/src.git ${FREEBSD_SRC_DIR}
    else
      \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} fetch --depth 1 origin ${FREEBSD_SRC_BRANCH}
      \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} checkout -B ${FREEBSD_SRC_BRANCH} FETCH_HEAD
      \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} reset --hard FETCH_HEAD
    fi

    \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} rev-parse HEAD
  "

  stage_config
  echo "Prepared FreeBSD ${FREEBSD_SRC_BRANCH} source and ${KERNEL_CONF}."
}

build_kernel() {
  prepare_source

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    JOBS=\${GO9_KERNEL_JOBS:-\$(sysctl -n hw.ncpu)}
    cd ${FREEBSD_SRC_DIR}
    \"\${DOAS}\" -n env MAKEOBJDIRPREFIX=${FREEBSD_OBJ_DIR} \
      make -j\"\${JOBS}\" kernel-toolchain
    \"\${DOAS}\" -n env MAKEOBJDIRPREFIX=${FREEBSD_OBJ_DIR} \
      make -j\"\${JOBS}\" -DALWAYS_CHECK_MAKE buildkernel KERNCONF=${KERNEL_CONF}
  "

  echo "Built ${KERNEL_CONF}."
}

install_kernel() {
  mount_existing_build_disk
  stage_config

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    test -d ${FREEBSD_SRC_DIR}/.git
    cd ${FREEBSD_SRC_DIR}
    \"\${DOAS}\" -n env MAKEOBJDIRPREFIX=${FREEBSD_OBJ_DIR} \
      make installkernel KERNCONF=${KERNEL_CONF} INSTKERNNAME=${KERNEL_INSTALL_NAME}
    test -f /boot/${KERNEL_INSTALL_NAME}/kernel
    test -f /boot/kernel/kernel
  "

  echo "Installed ${KERNEL_CONF} under /boot/${KERNEL_INSTALL_NAME}; GENERIC was not replaced."
}

validate_running_kernel() {
  require_vm

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    IDENT=\$(sysctl -n kern.ident)
    if [ \"\${IDENT}\" != ${KERNEL_CONF} ]; then
      echo \"expected kern.ident=${KERNEL_CONF}, got \${IDENT}\" >&2
      exit 1
    fi

    BOOTFILE=\$(sysctl -n kern.bootfile)
    if [ \"\${BOOTFILE}\" != /boot/${KERNEL_INSTALL_NAME}/kernel ]; then
      echo \"expected kern.bootfile=/boot/${KERNEL_INSTALL_NAME}/kernel, got \${BOOTFILE}\" >&2
      exit 1
    fi

    /usr/sbin/config -x \"\${BOOTFILE}\" > /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+VIMAGE([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+RACCT([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+RCTL([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+CAPABILITY_MODE([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+CAPABILITIES([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*device[[:space:]]+pf([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*device[[:space:]]+if_bridge([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*device[[:space:]]+epair([[:space:]]|$)' /tmp/go9-running-kernel.conf

    test \"\$(sysctl -n kern.racct.enable)\" = 1
    ifconfig -C | awk '{ for (i = 1; i <= NF; i++) print \$i }' | grep -qx bridge
    ifconfig -C | awk '{ for (i = 1; i <= NF; i++) print \$i }' | grep -qx epair
    test -c /dev/pf
    \"\${DOAS}\" -n service go9 onestatus

    echo \"running kernel: \${IDENT}\"
    uname -a
  "

  "${ROOT}/freebsd/devvm/test.sh"
  echo "Validated ${KERNEL_CONF}, VIMAGE, RACCT/RCTL, Capsicum, PF, bridge, epair, and go9."
}

wait_for_ssh_down() {
  i=0
  while [ "${i}" -lt 24 ]; do
    if ! ssh_guest 'true' >/dev/null 2>&1; then
      return 0
    fi
    i=$((i+1))
    printf .
    sleep 5
  done
  echo
  echo "VM did not leave SSH during the requested reboot." >&2
  return 1
}

wait_for_ssh_up() {
  i=0
  while [ "${i}" -lt 90 ]; do
    if ssh_guest 'true' >/dev/null 2>&1; then
      return 0
    fi
    i=$((i+1))
    printf .
    sleep 5
  done
  echo
  echo "Timed out waiting for the VM after the one-shot kernel boot." >&2
  echo "Because nextboot is one-shot, another normal reboot should fall back to GENERIC." >&2
  echo "Inspect serial output with: make freebsd-vm-logs" >&2
  return 1
}

boot_test() {
  require_vm
  ssh_guest "set -eu
    test -f /boot/${KERNEL_INSTALL_NAME}/kernel
    test -f /boot/kernel/kernel
    /usr/local/bin/doas -n nextboot -k ${KERNEL_INSTALL_NAME}
    test -f /boot/nextboot.conf
    cat /boot/nextboot.conf
  "

  echo "Rebooting once into ${KERNEL_CONF}; GENERIC remains the normal fallback."
  ssh_guest "/usr/local/bin/doas -n shutdown -r now" >/dev/null 2>&1 || true

  printf 'Waiting for SSH to stop'
  wait_for_ssh_down
  echo
  printf 'Waiting for one-shot ${KERNEL_CONF} boot'
  wait_for_ssh_up
  echo
  validate_running_kernel
}

show_status() {
  require_vm
  ssh_guest "
    echo 'running:'
    uname -a
    sysctl -n kern.ident
    sysctl -n kern.bootfile
    echo 'installed alternate kernel:'
    ls -ld /boot/${KERNEL_INSTALL_NAME} 2>/dev/null || true
    echo 'GENERIC fallback:'
    ls -l /boot/kernel/kernel 2>/dev/null || true
    echo 'nextboot configuration:'
    cat /boot/nextboot.conf 2>/dev/null || echo '(none)'
    echo 'kernel build disk:'
    geom disk list | awk '
      /^Geom name:/ { disk = \$3 }
      /^[[:space:]]*ident: ${BUILD_DISK_IDENT}[[:space:]]*\$/ { print disk }
    '
    mount -p | awk '\$1 == \"/dev/gpt/${BUILD_LABEL}\" { print }'
    df -h ${BUILD_MOUNT} 2>/dev/null || true
    echo 'source revision:'
    git -C ${FREEBSD_SRC_DIR} rev-parse HEAD 2>/dev/null || true
  "
}

clean_build_disk() {
  if [ -f "${PID_FILE}" ]; then
    PID=$(cat "${PID_FILE}" 2>/dev/null || true)
    if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
      echo "Stop the FreeBSD VM before removing the kernel build disk: make freebsd-vm-down" >&2
      exit 1
    fi
  fi

  rm -f "${KERNEL_BUILD_IMAGE}"
  echo "Removed persistent kernel build disk: ${KERNEL_BUILD_IMAGE}"
}

case "${1:-}" in
  prepare) prepare_source ;;
  build) build_kernel ;;
  install) install_kernel ;;
  test) validate_running_kernel ;;
  boot-test) boot_test ;;
  status) show_status ;;
  clean-build-disk) clean_build_disk ;;
  *) usage >&2; exit 2 ;;
esac
