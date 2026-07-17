#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"

ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" '
  set -eu
  DOAS=/usr/local/bin/doas

  freebsd-version | grep -q "15.1-RELEASE"
  file /usr/local/sbin/go9 | grep -Eiq "FreeBSD.*x86-64|ELF 64-bit.*FreeBSD"

  "$DOAS" -n service go9 onestatus
  test "$("$DOAS" -n stat -f %Lp /run/go9)" = "700"
  test "$("$DOAS" -n stat -f %Lp /run/go9/control.sock)" = "600"
'

curl -fsS "http://127.0.0.1:${GO9_VM_WEB_PORT}/" \
  | tee "${GO9_VM_DIR}/dashboard.html" \
  | grep -q 'GoSense9 Dashboard'

curl -fsS "http://127.0.0.1:${GO9_VM_WEB_PORT}/system/status" \
  | tee "${GO9_VM_DIR}/status.html" \
  | grep -q 'freebsd'

grep -q 'amd64' "${GO9_VM_DIR}/status.html"

if grep -E 'https?://|unpkg\.com|cdn' "${GO9_VM_DIR}/dashboard.html" "${GO9_VM_DIR}/status.html"; then
  echo "web assets depend on the Internet" >&2
  exit 1
fi

echo "GoSense9 dashboard: http://127.0.0.1:${GO9_VM_WEB_PORT}"
echo "FreeBSD SSH: make freebsd-vm-shell"
