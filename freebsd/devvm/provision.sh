#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
cd "${ROOT}"
CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 go build -o "${GO9_VM_DIR}/go9-freebsd-amd64" ./cmd/go9
scp ${SCP_OPTS} "${GO9_VM_DIR}/go9-freebsd-amd64" "${VM_USER}@127.0.0.1:/tmp/go9"
scp ${SCP_OPTS} "freebsd/rc.d/go9" "${VM_USER}@127.0.0.1:/tmp/go9.rc"
ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" 'set -eu; DOAS=/usr/local/bin/doas; "$DOAS" -n install -o root -g wheel -m 0555 /tmp/go9 /usr/local/sbin/go9; "$DOAS" -n install -o root -g wheel -m 0555 /tmp/go9.rc /usr/local/etc/rc.d/go9; "$DOAS" -n sysrc go9_enable=YES go9_socket=/run/go9/control.sock go9_web_addr=0.0.0.0:8080 >/dev/null; "$DOAS" -n service go9 restart || "$DOAS" -n service go9 start'
echo "Provisioned go9 service."
