#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "${ROOT}/freebsd/devvm/config.sh"
cd "${ROOT}"
CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 go build -o "${GO9_VM_DIR}/go9-freebsd-amd64" ./cmd/go9
scp ${SSH_OPTS} "${GO9_VM_DIR}/go9-freebsd-amd64" "${VM_USER}@127.0.0.1:/tmp/go9"
scp ${SSH_OPTS} "freebsd/rc.d/go9" "${VM_USER}@127.0.0.1:/tmp/go9.rc"
scp ${SSH_OPTS} "freebsd/config/rc.conf" "${VM_USER}@127.0.0.1:/tmp/go9.rc.conf"
ssh ${SSH_OPTS} "${VM_USER}@127.0.0.1" 'set -eu; sudo install -o root -g wheel -m 0555 /tmp/go9 /usr/local/sbin/go9; sudo install -o root -g wheel -m 0555 /tmp/go9.rc /usr/local/etc/rc.d/go9; sudo sh -c "cat /tmp/go9.rc.conf >> /etc/rc.conf"; sudo service go9 enable || true; sudo service go9 restart'
echo "Provisioned go9 service."
