#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

KERNEL_CONF=GO9_VM
KERNEL_INSTALL_NAME=kernel.go9vm
FREEBSD_SRC_BRANCH=releng/15.1
FREEBSD_SRC_DIR=/usr/local/src/go9-freebsd-src
FREEBSD_OBJ_DIR=/usr/obj/go9
MIN_FREE_KB=2500000

usage() {
  cat <<'EOF'
usage: sh freebsd/kernel/kernel.sh <prepare|build|install|test|boot-test|status>

  prepare    install Git, obtain releng/15.1 source, and stage GO9_VM
  build      build the kernel toolchain, GO9_VM kernel, and selected modules
  install    install under /boot/kernel.go9vm without replacing GENERIC
  test       validate the currently running kernel and GoSense9 service
  boot-test  schedule one GO9_VM boot with nextboot, reboot, wait, and test
  status     show source, installed kernel, nextboot, and running-kernel state
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

stage_config() {
  scp ${SCP_OPTS} "${ROOT}/freebsd/kernel/${KERNEL_CONF}" \
    "${VM_USER}@127.0.0.1:/tmp/${KERNEL_CONF}"
  ssh_guest "set -eu; /usr/local/bin/doas -n install -o root -g wheel -m 0644 /tmp/${KERNEL_CONF} ${FREEBSD_SRC_DIR}/sys/amd64/conf/${KERNEL_CONF}"
}

prepare_source() {
  require_vm

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    AVAILABLE_KB=\$(df -k /usr/local | awk 'NR == 2 { print \$4 }')
    if [ \"\${AVAILABLE_KB}\" -lt ${MIN_FREE_KB} ]; then
      echo \"GO9_VM build requires at least ${MIN_FREE_KB} KiB free; available: \${AVAILABLE_KB} KiB\" >&2
      exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
      \"\${DOAS}\" -n pkg install -y git
    fi

    if [ ! -d ${FREEBSD_SRC_DIR}/.git ]; then
      if [ -e ${FREEBSD_SRC_DIR} ]; then
        echo \"Refusing to replace unmanaged source path: ${FREEBSD_SRC_DIR}\" >&2
        exit 1
      fi
      \"\${DOAS}\" -n mkdir -p /usr/local/src ${FREEBSD_OBJ_DIR}
      \"\${DOAS}\" -n git clone --depth 1 --single-branch --branch ${FREEBSD_SRC_BRANCH} \
        https://git.FreeBSD.org/src.git ${FREEBSD_SRC_DIR}
    else
      \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} fetch --depth 1 origin ${FREEBSD_SRC_BRANCH}
      \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} checkout -B ${FREEBSD_SRC_BRANCH} FETCH_HEAD
      \"\${DOAS}\" -n git -C ${FREEBSD_SRC_DIR} reset --hard FETCH_HEAD
    fi

    \"\${DOAS}\" -n mkdir -p ${FREEBSD_OBJ_DIR}
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
  require_vm
  stage_config

  ssh_guest "set -eu
    DOAS=/usr/local/bin/doas
    test -d ${FREEBSD_SRC_DIR}/.git
    cd ${FREEBSD_SRC_DIR}
    \"\${DOAS}\" -n env MAKEOBJDIRPREFIX=${FREEBSD_OBJ_DIR} \
      make installkernel KERNCONF=${KERNEL_CONF} INSTKERNNAME=${KERNEL_INSTALL_NAME}
    test -f /boot/${KERNEL_INSTALL_NAME}/kernel
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
    test \"\${BOOTFILE}\" = /boot/${KERNEL_INSTALL_NAME}/kernel
    /usr/sbin/config -x \"\${BOOTFILE}\" > /tmp/go9-running-kernel.conf

    grep -Eq '^[[:space:]]*options[[:space:]]+VIMAGE([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+RACCT([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+RCTL([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+CAPABILITY_MODE([[:space:]]|$)' /tmp/go9-running-kernel.conf
    grep -Eq '^[[:space:]]*options[[:space:]]+CAPABILITIES([[:space:]]|$)' /tmp/go9-running-kernel.conf

    test \"\$(sysctl -n kern.racct.enable)\" = 1
    ifconfig -C | tr ' ' '\n' | grep -qx bridge
    ifconfig -C | tr ' ' '\n' | grep -qx epair
    \"\${DOAS}\" -n pfctl -s info >/dev/null
    \"\${DOAS}\" -n service go9 onestatus

    echo \"running kernel: \${IDENT}\"
    uname -a
  "

  "${ROOT}/freebsd/devvm/test.sh"
  echo "Validated ${KERNEL_CONF}, VIMAGE, RACCT/RCTL, Capsicum, PF, bridge, epair, and go9."
}

wait_for_reboot() {
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
  echo "The next normal boot should fall back to GENERIC. Inspect: make freebsd-vm-logs" >&2
  return 1
}

boot_test() {
  require_vm
  ssh_guest "set -eu
    test -f /boot/${KERNEL_INSTALL_NAME}/kernel
    /usr/local/bin/doas -n nextboot -k ${KERNEL_INSTALL_NAME}
    /usr/local/bin/doas -n shutdown -r now
  " >/dev/null 2>&1 || true

  printf 'Waiting for one-shot ${KERNEL_CONF} boot'
  sleep 8
  wait_for_reboot
  echo
  validate_running_kernel
}

show_status() {
  require_vm
  ssh_guest "
    echo 'running:'
    uname -a
    sysctl -n kern.ident
    echo 'installed alternate kernel:'
    ls -ld /boot/${KERNEL_INSTALL_NAME} 2>/dev/null || true
    echo 'nextboot configuration:'
    /usr/local/bin/doas -n nextboot -l 2>/dev/null || true
    echo 'source revision:'
    git -C ${FREEBSD_SRC_DIR} rev-parse HEAD 2>/dev/null || true
  "
}

case "${1:-}" in
  prepare) prepare_source ;;
  build) build_kernel ;;
  install) install_kernel ;;
  test) validate_running_kernel ;;
  boot-test) boot_test ;;
  status) show_status ;;
  *) usage >&2; exit 2 ;;
esac
