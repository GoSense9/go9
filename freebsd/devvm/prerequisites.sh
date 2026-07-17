#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
need(){ command -v "$1" >/dev/null 2>&1 || { echo "missing required command: $1" >&2; exit 1; }; }
for c in qemu-system-x86_64 qemu-img ssh scp ssh-keygen curl sha256sum go make; do need "$c"; done
if [ ! -e /dev/kvm ]; then echo "warning: /dev/kvm is not available; QEMU may be slow or fail" >&2; fi
mkdir -p "${GO9_VM_DIR}"
echo "FreeBSD development prerequisites found."
